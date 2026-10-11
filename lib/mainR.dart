// main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_sender/sms_sender.dart';

void main() {
  runApp(const SMSGatewayApp());
}

class SMSGatewayApp extends StatelessWidget {
  const SMSGatewayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MalaTrade SMS Gateway',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8C00),
          primary: const Color(0xFFFF8C00),
          surface: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF8C00),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      home: const MainTabContainer(),
    );
  }
}

class MainTabContainer extends StatefulWidget {
  const MainTabContainer({super.key});

  @override
  State<MainTabContainer> createState() => _MainTabContainerState();
}

class _MainTabContainerState extends State<MainTabContainer> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    GatewayDashboard(),
    SettingsView(),
    DocumentationView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MalaTrade SMS Gateway"),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFF8C00).withOpacity(0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFFFF8C00)),
              label: 'Console',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFFFF8C00)),
              label: 'Settings',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded, color: Color(0xFFFF8C00)),
              label: 'Docs',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: LIVE DASHBOARD & CONSOLE
// -----------------------------------------------------------------------------
class GatewayDashboard extends StatefulWidget {
  const GatewayDashboard({super.key});

  @override
  State<GatewayDashboard> createState() => _GatewayDashboardState();
}

class _GatewayDashboardState extends State<GatewayDashboard> {
  Timer? _pollingTimer;
  bool _isRunning = false;
  bool _isProcessing = false;
  final List<String> _logs = [];

  String _baseUrl = "https://malatrade.com/api";
  String _apiKey = "DEFAULT_SECRET_KEY";
  int _intervalSeconds = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseUrl = prefs.getString('baseUrl') ?? "https://malatrade.com/api";
      _apiKey = prefs.getString('apiKey') ?? "DEFAULT_SECRET_KEY";
      _intervalSeconds = prefs.getInt('intervalSeconds') ?? 10;
    });
  }

  void _addLog(String log) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        "${DateTime.now().toLocal().toString().split(' ')[1].substring(0, 8)}: $log",
      );
    });
  }

  void _togglePolling() async {
    await _loadSettings();

    if (_isRunning) {
      _pollingTimer?.cancel();
      setState(() {
        _isRunning = false;
      });
      _addLog("Polling engine stopped.");
    } else {
      setState(() {
        _isRunning = true;
      });
      _addLog("Polling active (Every ${_intervalSeconds}s)");
      _fetchAndDispatchSMS();
      _pollingTimer = Timer.periodic(
        Duration(seconds: _intervalSeconds),
        (_) => _fetchAndDispatchSMS(),
      );
    }
  }

  Future<void> _fetchAndDispatchSMS() async {
    if (_isProcessing) return;
    _isProcessing = true;

    final cleanBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;

    try {
      final response = await http.get(
        Uri.parse('$cleanBaseUrl/get-pending-sms/'),
        headers: {
          'X-Api-Key': _apiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> pendingMessages = jsonDecode(response.body);

        if (pendingMessages.isNotEmpty) {
          _addLog("📥 Fetched ${pendingMessages.length} SMS from queue.");

          for (var smsData in pendingMessages) {
            final int smsId = smsData['id'];
            final String phoneNumber = smsData['phone_number'] ?? '';
            final String message = smsData['message'] ?? '';

            if (phoneNumber.isEmpty || message.isEmpty) {
              _addLog("⚠️ Skipping invalid SMS #$smsId");
              continue;
            }

            _addLog("📱 Dispatching #$smsId to $phoneNumber...");

            await SmsSender.sendSms(
              phoneNumber: phoneNumber,
              message: message,
            );

            _addLog("✅ Sent #$smsId. Notifying server...");
            await _markSmsAsSent(cleanBaseUrl, smsId);
          }
        }
      } else if (response.statusCode == 401) {
        _addLog("Auth Failed: Invalid X-Api-Key.");
      } else {
        _addLog("Server responded with HTTP ${response.statusCode}");
      }
    } catch (e) {
      _addLog("Network/SMS Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _markSmsAsSent(String cleanBaseUrl, int smsId) async {
    try {
      final response = await http.post(
        Uri.parse('$cleanBaseUrl/mark-sms-sent/'),
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
        body: jsonEncode({
          'sms_id': smsId,
          'status': 'SENT',
          'gateway_key': _apiKey,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        _addLog("Server confirmed status for #$smsId");
      }
    } catch (e) {
      _addLog("Confirmation error #$smsId: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: _isRunning ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRunning ? "ENGINE ONLINE" : "ENGINE OFFLINE",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _isRunning ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRunning ? "Polling every ${_intervalSeconds}s..." : "Tap switch to initiate dispatch",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: _isRunning,
                        onChanged: (_) => _togglePolling(),
                        activeColor: const Color(0xFF22C55E),
                      ),
                    ],
                  ),
                  Divider(height: 28, color: Colors.grey.shade200),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Colors.blueGrey, size: 20),
                      const SizedBox(width: 8),
                      const Text("API: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(
                        child: SelectableText(
                          "$_baseUrl/get-pending-sms/",
                          style: const TextStyle(
                            color: Color(0xFFFF8C00),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 20, color: Color(0xFF1E293B)),
              const SizedBox(width: 8),
              Text(
                "Live Log Stream",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        "Console Idle.\nToggle engine ON to process queues.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: CONFIGURATION & DEVELOPER CREDITS
// -----------------------------------------------------------------------------
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _intervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('baseUrl') ?? "https://malatrade.com/api";
      _keyController.text = prefs.getString('apiKey') ?? "DEFAULT_SECRET_KEY";
      _intervalController.text = (prefs.getInt('intervalSeconds') ?? 10).toString();
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('baseUrl', _urlController.text.trim());
      await prefs.setString('apiKey', _keyController.text.trim());
      await prefs.setInt('intervalSeconds', int.parse(_intervalController.text.trim()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Gateway settings updated successfully!"),
            backgroundColor: const Color(0xFF22C55E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Gateway Configuration",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Set your custom server credentials to pair this device with your platform.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: "Server Base API URL",
                        hintText: "https://yourdomain.com/api",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.dns_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Please enter a valid URL";
                        if (!val.startsWith("http://") && !val.startsWith("https://")) {
                          return "URL must start with http:// or https://";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        labelText: "X-Api-Key (Auth Secret)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.key_outlined),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? "API key is required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Polling Interval (Seconds)",
                        hintText: "10",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.timer_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter polling interval";
                        final numVal = int.tryParse(val);
                        if (numVal == null || numVal < 2) return "Interval must be at least 2 seconds";
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save_rounded, color: Colors.white),
                        label: const Text(
                          "SAVE CONFIGURATION",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8C00),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // DEVELOPER CREDITS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.code_rounded, color: Color(0xFFFF8C00)),
                        SizedBox(width: 8),
                        Text(
                          "Developer Credits",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Isaac Kakodwa",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Python Developer | Data Analyst | Agribusiness Management",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        SelectableText(
                          "0993344416",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        SelectableText(
                          "kakodwaisaac@gmail.com",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: EXTENSIVE DEVELOPER INTEGRATION DOCS
// -----------------------------------------------------------------------------
class DocumentationView extends StatelessWidget {
  const DocumentationView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MalaTrade Open Gateway Specs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Transforms Android devices with an active SIM into automated SMS gateways. "
                  "Polls your database queue via HTTP(S) and dispatches messages locally.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                DocSectionHeader(
                  title: "1. System Architecture & Flow",
                  icon: Icons.alt_route_rounded,
                ),
                SizedBox(height: 12),
                Text(
                  "1. Backend inserts SMS with status = 'QUEUED'.\n"
                  "2. App fetches /get-pending-sms/ every X seconds.\n"
                  "3. Backend returns messages & locks them to 'PROCESSING'.\n"
                  "4. App dispatches messages sequentially via local SIM.\n"
                  "5. App posts /mark-sms-sent/ with status = 'SENT' or 'FAILED'.",
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        const CodeDocTile(
          language: "Endpoint 1: Fetch Pending SMS (GET)",
          codeSnippet: r'''
URL: {BASE_URL}/get-pending-sms/
Headers: 
  X-Api-Key: YOUR_CONFIGURED_SECRET_KEY
  Accept: application/json

Response (200 OK):
[
  {
    "id": 101,
    "phone_number": "+265991234567",
    "message": "MalaTrade: Your account is ready!"
  }
]''',
        ),

        const CodeDocTile(
          language: "Endpoint 2: Confirm Dispatch (POST)",
          codeSnippet: r'''
URL: {BASE_URL}/mark-sms-sent/
Headers: 
  X-Api-Key: YOUR_CONFIGURED_SECRET_KEY
  Content-Type: application/json

Payload Body:
{
  "sms_id": 101,
  "status": "SENT",
  "gateway_key": "YOUR_CONFIGURED_SECRET_KEY"
}''',
        ),

        const SizedBox(height: 12),
        const DocSectionHeader(
          title: "2. Backend Implementations",
          icon: Icons.code_rounded,
        ),
        const SizedBox(height: 12),

        const CodeDocTile(
          language: "Python / Django",
          codeSnippet: r'''
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import SMSQueue

API_KEY = "YOUR_CONFIGURED_SECRET_KEY"

def get_pending_sms(request):
    if request.headers.get('X-Api-Key') != API_KEY:
        return JsonResponse({'error': 'Unauthorized'}, status=401)
        
    pending = SMSQueue.objects.filter(status='QUEUED')[:10]
    data = [{'id': m.id, 'phone_number': m.phone_number, 'message': m.message} for m in pending]
    
    SMSQueue.objects.filter(id__in=[m.id for m in pending]).update(status='PROCESSING')
    return JsonResponse(data, safe=False)

@csrf_exempt
def mark_sms_sent(request):
    if request.method == 'POST':
        if request.headers.get('X-Api-Key') != API_KEY:
            return JsonResponse({'error': 'Unauthorized'}, status=401)
            
        data = json.loads(request.body)
        SMSQueue.objects.filter(id=data.get('sms_id')).update(status=data.get('status', 'SENT'))
        return JsonResponse({'status': 'success'})
    return JsonResponse({'error': 'Method not allowed'}, status=405)''',
        ),

        const CodeDocTile(
          language: "PHP (Vanilla)",
          codeSnippet: r'''
<?php
header('Content-Type: application/json');
$apiKey = "YOUR_CONFIGURED_SECRET_KEY";

if ($_SERVER['HTTP_X_API_KEY'] !== $apiKey) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

$pdo = new PDO('mysql:host=localhost;dbname=malatrade', 'db_user', 'db_pass');

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->query("SELECT id, phone_number, message FROM sms_queue WHERE status = 'QUEUED' LIMIT 10");
    $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($messages)) {
        $ids = implode(',', array_column($messages, 'id'));
        $pdo->exec("UPDATE sms_queue SET status = 'PROCESSING' WHERE id IN ($ids)");
    }
    echo json_encode($messages);
} 

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $stmt = $pdo->prepare("UPDATE sms_queue SET status = ? WHERE id = ?");
    $stmt->execute([$input['status'], $input['sms_id']]);
    echo json_encode(['status' => 'success']);
}
?>''',
        ),

        const CodeDocTile(
          language: "Node.js / Express.js",
          codeSnippet: r'''
const express = require('express');
const app = express();
app.use(express.json());

const API_KEY = "YOUR_CONFIGURED_SECRET_KEY";

app.use((req, res, next) => {
  if (req.headers['x-api-key'] !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

app.get('/api/get-pending-sms', async (req, res) => {
  const [rows] = await db.execute("SELECT id, phone_number, message FROM sms_queue WHERE status = 'QUEUED' LIMIT 10");
  if (rows.length > 0) {
    const ids = rows.map(r => r.id).join(',');
    await db.execute(`UPDATE sms_queue SET status = 'PROCESSING' WHERE id IN (${ids})`);
  }
  res.json(rows);
});

app.post('/api/mark-sms-sent', async (req, res) => {
  const { sms_id, status } = req.body;
  await db.execute("UPDATE sms_queue SET status = ? WHERE id = ?", [status, sms_id]);
  res.json({ status: 'success' });
});''',
        ),

        const CodeDocTile(
          language: "C# / .NET Core Web API",
          codeSnippet: r'''
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[ApiController]
[Route("api")]
public class SmsController : ControllerBase
{
    private const string ApiKey = "YOUR_CONFIGURED_SECRET_KEY";
    private readonly AppDbContext _context;

    public SmsController(AppDbContext context) => _context = context;

    [HttpGet("get-pending-sms")]
    public async Task<IActionResult> GetPendingSms()
    {
        if (Request.Headers["X-Api-Key"] != ApiKey) return Unauthorized();

        var pending = await _context.SmsQueue
            .Where(s => s.Status == "QUEUED")
            .Take(10)
            .ToListAsync();

        foreach (var item in pending) { item.Status = "PROCESSING"; }
        await _context.SaveChangesAsync();

        return Ok(pending.Select(s => new { s.Id, s.PhoneNumber, s.Message }));
    }

    [HttpPost("mark-sms-sent")]
    public async Task<IActionResult> MarkSmsSent([FromBody] SmsUpdateDto dto)
    {
        if (Request.Headers["X-Api-Key"] != ApiKey) return Unauthorized();

        var sms = await _context.SmsQueue.FindAsync(dto.SmsId);
        if (sms != null)
        {
            sms.Status = dto.Status ?? "SENT";
            await _context.SaveChangesAsync();
        }
        return Ok(new { status = "success" });
    }
}''',
        ),
      ],
    );
  }
}

class DocSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const DocSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFF8C00)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class CodeDocTile extends StatelessWidget {
  final String language;
  final String codeSnippet;

  const CodeDocTile({
    super.key,
    required this.language,
    required this.codeSnippet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language,
                  style: const TextStyle(
                    color: Color(0xFFFF8C00),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codeSnippet));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$language snippet copied!"),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: SelectableText(
              codeSnippet.trim(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF38BDF8),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}