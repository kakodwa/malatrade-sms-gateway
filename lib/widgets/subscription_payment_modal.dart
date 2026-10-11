import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'visa_checkout_webview.dart';

class SubscriptionPaymentModal extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  final VoidCallback onSuccess;

  const SubscriptionPaymentModal({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onSuccess,
  });

  @override
  State<SubscriptionPaymentModal> createState() => _SubscriptionPaymentModalState();
}

class _SubscriptionPaymentModalState extends State<SubscriptionPaymentModal> {
  String _selectedMethod = 'airtel_money';
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  Timer? _verifyTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _verifyTimer?.cancel();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if ((_selectedMethod == 'airtel_money' || _selectedMethod == 'tnm_mpamba') &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter phone number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cleanBaseUrl = widget.baseUrl.endsWith('/')
          ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
          : widget.baseUrl;

      final res = await http.post(
        Uri.parse('$cleanBaseUrl/payments/initiate/'),
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': widget.apiKey,
        },
        body: jsonEncode({
          'payment_method': _selectedMethod,
          'phone_number': _phoneController.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['payment_reference'] != null) {
        final ref = data['payment_reference'];

        if (_selectedMethod == 'visa_card' && data['checkout_url'] != null) {
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisaCheckoutWebView(
                checkoutUrl: data['checkout_url'],
                onSuccess: () => _pollPaymentStatus(cleanBaseUrl, ref),
              ),
            ),
          );
        } else {
          _showPromptDialog();
          _pollPaymentStatus(cleanBaseUrl, ref);
        }
      } else {
        throw Exception(data['error'] ?? "Failed to initiate payment");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPromptDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF8C00)),
            SizedBox(height: 16),
            Text("Check your phone and enter PIN to complete payment.", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _pollPaymentStatus(String cleanBaseUrl, String ref) {
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final res = await http.get(Uri.parse('$cleanBaseUrl/payments/status/$ref/'));
        final data = jsonDecode(res.body);

        if (data['status'] == 'completed') {
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            widget.onSuccess();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Subscription activated successfully!"),
                backgroundColor: Color(0xFF22C55E),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Monthly Plan Subscription", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("MWK 15,000 / month - Unlimited SMS Gateway Routing", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),

          RadioListTile<String>(
            title: const Text("Airtel Money"),
            value: "airtel_money",
            groupValue: _selectedMethod,
            activeColor: const Color(0xFFFF8C00),
            onChanged: (v) => setState(() => _selectedMethod = v!),
          ),
          RadioListTile<String>(
            title: const Text("TNM Mpamba"),
            value: "tnm_mpamba",
            groupValue: _selectedMethod,
            activeColor: const Color(0xFFFF8C00),
            onChanged: (v) => setState(() => _selectedMethod = v!),
          ),
          RadioListTile<String>(
            title: const Text("Visa / Mastercard"),
            value: "visa_card",
            groupValue: _selectedMethod,
            activeColor: const Color(0xFFFF8C00),
            onChanged: (v) => setState(() => _selectedMethod = v!),
          ),

          if (_selectedMethod != 'visa_card') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Mobile Money Number",
                hintText: "e.g. 0993344416",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("PAY MWK 15,000 NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}