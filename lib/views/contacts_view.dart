import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => ContactsViewState();
}

class ContactsViewState extends State<ContactsView> {
  List<dynamic> _groups = [];
  bool _isLoading = true;
  String _baseUrl = "";
  String _apiKey = "";

  @override
  void initState() {
    super.initState();
    reloadCredentials();
  }

  // 🔄 PUBLIC METHOD: Triggered from parent container, tab switch, login, or logout
  Future<void> reloadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final newBaseUrl = prefs.getString('baseUrl') ?? "https://malatrade.com/api";
    final newApiKey = prefs.getString('apiKey') ?? "";

    // 🔒 CLEAR DATA IMMEDIATELY IF LOGGED OUT / UNLICENSED
    if (newApiKey.isEmpty || newApiKey == "DEFAULT_SECRET_KEY") {
      if (mounted) {
        setState(() {
          _baseUrl = newBaseUrl;
          _apiKey = "";
          _groups = []; // 👈 Prevents old contacts from staying on screen
          _isLoading = false;
        });
      }
      return;
    }

    // 🔓 FETCH FRESH DATA IF LOGGED IN
    if (mounted) {
      setState(() {
        _baseUrl = newBaseUrl;
        _apiKey = newApiKey;
        _isLoading = true;
      });
    }
    await _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    if (_apiKey.isEmpty || _apiKey == "DEFAULT_SECRET_KEY") {
      if (mounted) {
        setState(() {
          _groups = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final cleanUrl = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      final res = await http.get(
        Uri.parse('$cleanUrl/contact-groups/'),
        headers: {'X-Api-Key': _apiKey, 'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _groups = data['groups'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _groups = []; // Clear on auth failure/401/402
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ DELETE GROUP CONFIRMATION DIALOG
  Future<void> _deleteGroup(int groupId, String groupName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete $groupName?"),
        content: const Text(
          "This will permanently delete this group and all contained contacts.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final cleanUrl = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      final res = await http.delete(
        Uri.parse('$cleanUrl/contact-groups/$groupId/'),
        headers: {'X-Api-Key': _apiKey},
      );

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group deleted successfully!")),
        );
        _fetchGroups();
      }
    }
  }

  // 🗑️ DELETE SINGLE CONTACT
  Future<void> _deleteContact(
      int groupId, int contactId, VoidCallback onDeleted) async {
    final cleanUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final res = await http.delete(
      Uri.parse('$cleanUrl/contact-groups/$groupId/contacts/$contactId/'),
      headers: {'X-Api-Key': _apiKey},
    );

    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact deleted")),
      );
      onDeleted();
      _fetchGroups();
    }
  }

  void _openCreateGroupModal() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Contact Group"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Group Name (e.g. Customers)",
              ),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: "Description (Optional)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              final cleanUrl = _baseUrl.endsWith('/')
                  ? _baseUrl.substring(0, _baseUrl.length - 1)
                  : _baseUrl;
              await http.post(
                Uri.parse('$cleanUrl/contact-groups/'),
                headers: {
                  'X-Api-Key': _apiKey,
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                }),
              );
              _fetchGroups();
            },
            child: const Text("CREATE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddContactModal(int groupId, String groupName) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isBulkMode = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("Add Contacts to $groupName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isBulkMode ? "Bulk Add Numbers" : "Single Contact"),
                  TextButton(
                    onPressed: () =>
                        setModalState(() => isBulkMode = !isBulkMode),
                    child: Text(
                      isBulkMode ? "Single Mode" : "Paste Multiple",
                      style: const TextStyle(
                        color: Color(0xFFFF8C00),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isBulkMode) ...[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Contact Name (Optional)",
                  ),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number (e.g. +265991234567)",
                  ),
                ),
              ] else ...[
                TextField(
                  controller: phoneCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: "Phone Numbers",
                    hintText:
                        "Paste numbers separated by commas or line breaks:\n+265991234567\n+265881234567",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
              ),
              onPressed: () async {
                final rawPhone = phoneCtrl.text.trim();
                if (rawPhone.isEmpty) return;

                Navigator.pop(context);
                final cleanUrl = _baseUrl.endsWith('/')
                    ? _baseUrl.substring(0, _baseUrl.length - 1)
                    : _baseUrl;

                if (!isBulkMode) {
                  await http.post(
                    Uri.parse('$cleanUrl/contact-groups/$groupId/contacts/'),
                    headers: {
                      'X-Api-Key': _apiKey,
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'name': nameCtrl.text.trim(),
                      'phone_number': rawPhone,
                    }),
                  );
                } else {
                  final List<String> numbers = rawPhone
                      .split(RegExp(r'[\n, ]+'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  for (var num in numbers) {
                    await http.post(
                      Uri.parse('$cleanUrl/contact-groups/$groupId/contacts/'),
                      headers: {
                        'X-Api-Key': _apiKey,
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({'phone_number': num}),
                    );
                  }
                }

                _fetchGroups();
              },
              child: const Text(
                "SAVE CONTACT(S)",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBroadcastModal(int groupId, String groupName) {
    final msgCtrl = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bulk Broadcast to: $groupName",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Enter broadcast SMS message...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          if (msgCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSending = true);

                          final cleanUrl = _baseUrl.endsWith('/')
                              ? _baseUrl.substring(0, _baseUrl.length - 1)
                              : _baseUrl;
                          final res = await http.post(
                            Uri.parse('$cleanUrl/send-bulk-sms/'),
                            headers: {
                              'X-Api-Key': _apiKey,
                              'Content-Type': 'application/json',
                            },
                            body: jsonEncode({
                              'group_id': groupId,
                              'message': msgCtrl.text.trim(),
                            }),
                          );

                          setModalState(() => isSending = false);
                          if (mounted) {
                            Navigator.pop(ctx);
                            final data = jsonDecode(res.body);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  data['message'] ??
                                      "Bulk broadcast queued successfully!",
                                ),
                                backgroundColor: const Color(0xFF22C55E),
                              ),
                            );
                          }
                        },
                  label: isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "QUEUE BULK BROADCAST",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewContactsModal(int groupId, String groupName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Contacts in $groupName",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<http.Response>(
                  future: http.get(
                    Uri.parse(
                      '${_baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl}/contact-groups/$groupId/contacts/',
                    ),
                    headers: {
                      'X-Api-Key': _apiKey,
                      'Accept': 'application/json',
                    },
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF8C00),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
                      return const Center(
                        child: Text("Failed to load contacts"),
                      );
                    }

                    final data = jsonDecode(snapshot.data!.body);
                    final List contacts = data['contacts'] ?? [];

                    if (contacts.isEmpty) {
                      return const Center(
                        child: Text("No contacts in this group yet."),
                      );
                    }

                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final c = contacts[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF7ED),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFFFF8C00),
                            ),
                          ),
                          title: Text(
                            c['name'] != null && c['name'].isNotEmpty
                                ? c['name']
                                : "Unnamed Contact",
                          ),
                          subtitle: Text(c['phone_number']),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              _deleteContact(groupId, c['id'], () {
                                setModalState(() {});
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _apiKey.isNotEmpty && _apiKey != "DEFAULT_SECRET_KEY"
          ? FloatingActionButton.extended(
              onPressed: _openCreateGroupModal,
              backgroundColor: const Color(0xFFFF8C00),
              icon: const Icon(Icons.group_add_rounded, color: Colors.white),
              label: const Text(
                "NEW GROUP",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFFFF8C00),
        onRefresh: () async {
          await reloadCredentials();
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
              )
            : (_apiKey.isEmpty || _apiKey == "DEFAULT_SECRET_KEY")
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          "Please sign in or configure your API Key in Settings to view contacts.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.5),
                        ),
                      ),
                    ],
                  )
                : _groups.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              "No contact groups found.\nPull down to refresh or create a new group.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final g = _groups[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                onTap: () =>
                                    _openViewContactsModal(g['id'], g['name']),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFFFF7ED),
                                  child: Icon(
                                    Icons.people_outline_rounded,
                                    color: Color(0xFFFF8C00),
                                  ),
                                ),
                                title: Text(
                                  g['name'],
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "${g['contact_count']} Contacts • Tap to view list",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF8C00),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _openBroadcastModal(g['id'], g['name']),
                                      child: const Text(
                                        "BROADCAST",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        color: Colors.blueGrey,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'add') {
                                          _openAddContactModal(g['id'], g['name']);
                                        } else if (value == 'delete') {
                                          _deleteGroup(g['id'], g['name']);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem<String>(
                                          value: 'add',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.person_add_alt_1_rounded,
                                                color: Color(0xFFFF8C00),
                                                size: 20,
                                              ),
                                              SizedBox(width: 10),
                                              Text("Add Contacts"),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                "Delete Group",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}