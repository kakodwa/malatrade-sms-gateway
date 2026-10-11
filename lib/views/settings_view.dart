import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback? onSettingsSaved;

  const SettingsView({super.key, this.onSettingsSaved});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _intervalController = TextEditingController();

  final _authUsernameController = TextEditingController();
  final _authEmailController = TextEditingController();
  final _authPasswordController = TextEditingController();

  bool _isAuthLoading = false;
  bool _isRegisterMode = false;
  bool _isLoggedIn = false;
  String _activeUsername = "";

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _intervalController.dispose();
    _authUsernameController.dispose();
    _authEmailController.dispose();
    _authPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('apiKey') ?? "DEFAULT_SECRET_KEY";
    final savedUser = prefs.getString('loggedInUser') ?? "";

    setState(() {
      _urlController.text = prefs.getString('baseUrl') ?? "http://127.0.0.1:8000/api";
      _keyController.text = savedKey;
      _intervalController.text = (prefs.getInt('intervalSeconds') ?? 10).toString();
      _activeUsername = savedUser;
      _isLoggedIn = savedKey != "DEFAULT_SECRET_KEY" && savedKey.isNotEmpty;
    });
  }

  Future<void> _processAuthentication() async {
    final username = _authUsernameController.text.trim();
    final password = _authPasswordController.text.trim();
    final email = _authEmailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username and Password are required")),
      );
      return;
    }

    setState(() => _isAuthLoading = true);

    try {
      final cleanBaseUrl = _urlController.text.trim().endsWith('/')
          ? _urlController.text.trim().substring(0, _urlController.text.trim().length - 1)
          : _urlController.text.trim();

      final endpoint = _isRegisterMode ? '/app-register/' : '/app-login/';

      final response = await http.post(
        Uri.parse('$cleanBaseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          if (_isRegisterMode) 'email': email,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['api_key'] != null) {
        final fetchedKey = data['api_key'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('apiKey', fetchedKey);
        await prefs.setString('baseUrl', cleanBaseUrl);
        await prefs.setString('loggedInUser', username);

        setState(() {
          _keyController.text = fetchedKey;
          _activeUsername = username;
          _isLoggedIn = true; // 🔓 Unlocks configuration form
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Authentication successful! Settings unlocked."),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
        }

        // Notify parent container so all tabs fetch fresh data automatically
        if (widget.onSettingsSaved != null) {
          widget.onSettingsSaved!();
        }
      } else {
        throw Exception(data['error'] ?? "Authentication failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Auth Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKey');
    await prefs.remove('loggedInUser');

    setState(() {
      _keyController.text = "DEFAULT_SECRET_KEY";
      _activeUsername = "";
      _isLoggedIn = false; // 🔒 Hides configuration form
      _authUsernameController.clear();
      _authPasswordController.clear();
      _authEmailController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged out successfully. Configuration forms hidden.")),
      );
    }

    if (widget.onSettingsSaved != null) {
      widget.onSettingsSaved!();
    }
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

      if (widget.onSettingsSaved != null) {
        widget.onSettingsSaved!();
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
            // 1. SHOW AUTH CARD WHEN LOGGED OUT
            if (!_isLoggedIn) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isRegisterMode ? "Create New Account" : "Sign In to Gateway",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _isRegisterMode = !_isRegisterMode);
                            },
                            child: Text(
                              _isRegisterMode ? "Need to Login?" : "New User? Register",
                              style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegisterMode
                            ? "Register an account to generate your secret key and access configuration settings."
                            : "Enter your registered credentials to unlock gateway configuration settings.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _authUsernameController,
                        decoration: InputDecoration(
                          labelText: "Username",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      if (_isRegisterMode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _authEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email Address (Optional)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _authPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: "Server Base API URL",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.dns_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAuthLoading ? null : _processAuthentication,
                          icon: const Icon(Icons.key_rounded, color: Colors.white),
                          label: _isAuthLoading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _isRegisterMode ? "CREATE ACCOUNT & UNLOCK SETTINGS" : "SIGN IN & UNLOCK SETTINGS",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8C00),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 2. SHOW USER CARD & PAIRING FORM ONLY WHEN LOGGED IN
            if (_isLoggedIn) ...[
              Card(
                color: const Color(0xFFFFF7ED),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFFF8C00),
                        child: Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeUsername.isNotEmpty ? _activeUsername : "Authenticated User",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Text("Status: Connected & Verified", style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                        label: const Text("LOGOUT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Active Gateway Pairing", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Server routing configurations bound to your account session.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: "Server Base API URL",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.dns_outlined),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? "URL required" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _keyController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "X-Api-Key (Auth Secret)",
                          helperText: "Locked to logged-in user record.",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: const Icon(Icons.verified_user_rounded, color: Colors.green),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? "API Key required" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Polling Interval (Seconds)",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.timer_outlined),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save_rounded, color: Colors.white),
                          label: const Text("SAVE CONFIGURATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8C00),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}