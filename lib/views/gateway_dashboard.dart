import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_sender/sms_sender.dart';
import '../widgets/subscription_payment_modal.dart';
import '../widgets/server_banner_carousel.dart';

class GatewayDashboard extends StatefulWidget {
  const GatewayDashboard({super.key});

  @override
  State<GatewayDashboard> createState() => _GatewayDashboardState();
}

class _GatewayDashboardState extends State<GatewayDashboard>
    with AutomaticKeepAliveClientMixin {
  Timer? _pollingTimer;
  bool _isRunning = false;
  bool _isProcessing = false;
  int _trialRemaining = 10;
  final List<String> _logs = [];

  String _baseUrl = "http://127.0.0.1:8000/api";
  String _apiKey = "DEFAULT_SECRET_KEY";
  int _intervalSeconds = 10;

  @override
  bool get wantKeepAlive => true;

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
      _baseUrl = prefs.getString('baseUrl') ?? "http://127.0.0.1:8000/api";
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
            if (!_isRunning) break;

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

            // Anti-spam carrier safety delay
            _addLog("⏱️ Anti-spam delay: waiting 3s before next SMS...");
            await Future.delayed(const Duration(seconds: 3));
          }
        }
      } else if (response.statusCode == 402) {
        _pollingTimer?.cancel();
        setState(() {
          _isRunning = false;
          _trialRemaining = 0;
        });
        _addLog("🔒 Trial Limit Reached / Subscription Required!");
        if (mounted) {
          _openSubscriptionModal();
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
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['trial_remaining'] != null) {
          setState(() {
            _trialRemaining = data['trial_remaining'];
          });
          _addLog("Server confirmed #$smsId (Free trial SMS remaining: $_trialRemaining)");
        }
      }
    } catch (e) {
      _addLog("Confirmation error #$smsId: $e");
    }
  }

  void _openSubscriptionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SubscriptionPaymentModal(
        baseUrl: _baseUrl,
        apiKey: _apiKey,
        onSuccess: () {
          _addLog("🎉 Subscription Payment Successful! Engine unlocked.");
          _togglePolling();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Server-Fetched Sliding Banner Carousel
          ServerBannerCarousel(baseUrl: _baseUrl),

          // Trial Status Banner Card
          Card(
            color: const Color(0xFFFFF7ED),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF8C00)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _trialRemaining > 0
                          ? "Free Trial Active: $_trialRemaining/10 SMS remaining"
                          : "Free Trial Expired! Plan required to send SMS.",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openSubscriptionModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Text("SUBSCRIBE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Operational Guidelines Notice Card
          Card(
            color: const Color(0xFFEFF6FF),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Important Setup Guidelines",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "• Before switching the engine ON, make sure you saved your configuration in the Settings tab.\n"
                          "• Make sure you have bought SMS bundles (TNM or Airtel for Malawi) or have credit in your phone.\n"
                          "• Do not switch off or close the app; it sends SMS only while running.\n"
                          "• For configuration with your app, follow the Documentation tab.",
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Engine Status Card
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

          // Live Log Stream Header
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

          // Terminal Console Container
          Container(
            height: 350,
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}