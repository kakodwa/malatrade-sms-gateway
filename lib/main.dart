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
      theme: ThemeData(
        primaryColor: const Color(0xFFFF8C00),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8C00),
          primary: const Color(0xFFFF8C00),
        ),
      ),
      home: const MainTabContainer(),
    );
  }
}

class MainTabContainer extends StatelessWidget {
  const MainTabContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Universal SMS Gateway",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFFF8C00),
          centerTitle: true,
          elevation: 2,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelColor: Colors.white70,
            labelColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_rounded), text: "Console"),
              Tab(icon: Icon(Icons.settings_rounded), text: "Settings"),
              Tab(icon: Icon(Icons.code_rounded), text: "Docs"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GatewayDashboard(),
            SettingsView(),
            DocumentationView(),
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
      _addLog("🛑 Polling engine stopped.");
    } else {
      setState(() {
        _isRunning = true;
      });
      _addLog("🚀 Polling active (Every ${_intervalSeconds}s)");
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
        _addLog("❌ Auth Failed: Invalid X-Api-Key.");
      } else {
        _addLog("⚠️ Server responded with HTTP ${response.statusCode}");
      }
    } catch (e) {
      _addLog("❌ Network/SMS Error: $e");
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
        _addLog("✔️ Server confirmed status for #$smsId");
      }
    } catch (e) {
      _addLog("❌ Confirmation error #$smsId: $e");
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
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: _isRunning ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _isRunning ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRunning ? "Polling every ${_intervalSeconds}s..." : "Tap switch to initiate dispatch",
                            style: TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: _isRunning,
                        onChanged: (_) => _togglePolling(),
                        activeColor: const Color(0xFFFF8C00),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      const Text("Target API: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: SelectableText(
                          "$_baseUrl/get-pending-sms/",
                          style: const TextStyle(
                            color: Color(0xFFFF8C00),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
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
              const Icon(Icons.terminal, size: 18, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                "Live Log Stream",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        "Console Idle.\nToggle switch ON to listen for backend tasks.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontFamily: 'monospace',
                              fontSize: 12.5,
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
// TAB 2: CONFIGURATION & SETTINGS
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
          const SnackBar(
            content: Text("✅ Gateway settings updated successfully!"),
            backgroundColor: Colors.green,
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
            const Text(
              "Gateway Configuration",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Enter your custom server settings to connect the gateway phone to your web app.",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "Server Base API URL",
                hintText: "https://yourdomain.com/api",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
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
              decoration: const InputDecoration(
                labelText: "X-Api-Key (Authentication Secret)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              validator: (val) => (val == null || val.isEmpty) ? "API key is required" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Polling Interval (Seconds)",
                hintText: "10",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Enter polling interval";
                final numVal = int.tryParse(val);
                if (numVal == null || numVal < 2) return "Interval must be at least 2 seconds";
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: const Text("SAVE CONFIGURATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      children: const [
        Text(
          "MalaTrade Open Gateway Specification",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          "This app transforms any Android device with an active SIM card into an automated SMS gateway. "
          "It polls your web server's database queue over HTTP(S), dispatches messages locally via carrier networks, and reports delivery status.",
          style: TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.4),
        ),
        SizedBox(height: 20),

        DocSectionHeader(
          title: "1. System Architecture & Flow",
          icon: Icons.alt_route_rounded,
        ),
        SizedBox(height: 8),
        Text(
          "1. Your Backend (Django/PHP/Node) inserts an SMS record into the database with status = 'QUEUED'.\n"
          "2. Gateway App sends an HTTP GET request to /get-pending-sms/ every X seconds.\n"
          "3. Backend returns unsent messages and sets their status to 'PROCESSING'.\n"
          "4. App sends messages sequentially via local SIM card.\n"
          "5. App hits HTTP POST /mark-sms-sent/ to set status = 'SENT' or 'FAILED'.",
          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
        ),
        SizedBox(height: 20),

        DocSectionHeader(
          title: "2. API Specifications & Contracts",
          icon: Icons.api_rounded,
        ),
        SizedBox(height: 10),

        CodeDocTile(
          language: "Endpoint 1: Fetch Pending SMS (GET)",
          codeSnippet: r'''
URL: {BASE_URL}/get-pending-sms/
Headers: 
  X-Api-Key: YOUR_CONFIGURED_SECRET_KEY
  Accept: application/json

Response (200 OK - JSON Array):
[
  {
    "id": 101,
    "phone_number": "+265991234567",
    "message": "MalaTrade: Your item #42 has been listed!"
  }
]''',
        ),

        CodeDocTile(
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
}

Response (200 OK):
{
  "status": "success",
  "message": "SMS status updated"
}''',
        ),

        DocSectionHeader(
          title: "3. Database Table Structure",
          icon: Icons.storage_rounded,
        ),
        SizedBox(height: 10),

        CodeDocTile(
          language: "SQL Schema (MySQL / PostgreSQL / SQLite)",
          codeSnippet: r'''
CREATE TABLE sms_queue (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'QUEUED', -- QUEUED, PROCESSING, SENT, FAILED
    error_log TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);''',
        ),

        DocSectionHeader(
          title: "4. Backend Implementations",
          icon: Icons.code_rounded,
        ),
        SizedBox(height: 10),

        CodeDocTile(
          language: "Python / Django (complete views.py)",
          codeSnippet: r'''
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
from .models import SMSQueue

API_KEY = "YOUR_CONFIGURED_SECRET_KEY"

def get_pending_sms(request):
    if request.headers.get('X-Api-Key') != API_KEY:
        return JsonResponse({'error': 'Unauthorized'}, status=401)
        
    pending = SMSQueue.objects.filter(status='QUEUED')[:10]
    data = [{'id': m.id, 'phone_number': m.phone_number, 'message': m.message} for m in pending]
    
    # Lock fetched messages
    SMSQueue.objects.filter(id__in=[m.id for m in pending]).update(status='PROCESSING')
    return JsonResponse(data, safe=False)

@csrf_exempt
def mark_sms_sent(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        if request.headers.get('X-Api-Key') != API_KEY:
            return JsonResponse({'error': 'Unauthorized'}, status=401)
            
        SMSQueue.objects.filter(id=data.get('sms_id')).update(status=data.get('status', 'SENT'))
        return JsonResponse({'status': 'updated'})
    return JsonResponse({'error': 'Method not allowed'}, status=405)''',
        ),

        CodeDocTile(
          language: "PHP (Vanilla API script)",
          codeSnippet: r'''
<?php
// api.php
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
    echo json_encode(['status' => 'updated']);
}
?>''',
        ),

        CodeDocTile(
          language: "Node.js / Express.js",
          codeSnippet: r'''
const express = require('express');
const app = express();
app.use(express.json());

const API_KEY = "YOUR_CONFIGURED_SECRET_KEY";

// Auth Middleware
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
  res.json({ status: 'updated' });
});''',
        ),

        DocSectionHeader(
          title: "5. Production & Carrier Guidelines",
          icon: Icons.shield_rounded,
        ),
        SizedBox(height: 8),
        Text(
          "• Phone Format: Ensure all phone numbers are formatted in E.164 standard (+265XXXXXXXXX for Malawi).\n"
          "• Rate Limiting: Do not queue more than 15 SMS per minute per SIM card to prevent mobile operators (Airtel/TNM) from blocking the card for spam.\n"
          "• Power & Battery: Set Android app battery usage settings to 'Unrestricted' so the OS does not kill background polling.\n"
          "• Message Length: Standard SMS messages are limited to 160 characters. Messages exceeding this count as multiple SMS segments.",
          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
        ),
        SizedBox(height: 24),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
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
                    fontSize: 13,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codeSnippet));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$language snippet copied!"),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E1E1E),
            child: SelectableText(
              codeSnippet.trim(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.lightBlueAccent,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}