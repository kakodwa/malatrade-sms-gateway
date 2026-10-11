import 'package:flutter/material.dart';
import 'gateway_dashboard.dart';
import 'contacts_view.dart';
import 'settings_view.dart';
import 'documentation_view.dart';

class MainTabContainer extends StatefulWidget {
  const MainTabContainer({super.key});

  @override
  State<MainTabContainer> createState() => _MainTabContainerState();
}

class _MainTabContainerState extends State<MainTabContainer> {
  int _currentIndex = 0;

  // Global Keys to command active states directly
  final GlobalKey<ContactsViewState> _contactsKey = GlobalKey<ContactsViewState>();

  void _handleSettingsOrLoginChanged() {
    // 1. Force ContactsView to immediately read new SharedPreferences credentials
    _contactsKey.currentState?.reloadCredentials();

    // 2. Automatically switch back to Console or Contacts tab after login
    setState(() {
      _currentIndex = 0; // Redirect to Console Dashboard
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Credentials updated! All tabs refreshed."),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MalaTrade SMS Gateway"),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const GatewayDashboard(),
          ContactsView(key: _contactsKey),
          SettingsView(onSettingsSaved: _handleSettingsOrLoginChanged),
          const DocumentationView(),
        ],
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

            // 🔄 ALWAYS force fresh pull when user taps Contacts tab (Tab 1)
            if (index == 1) {
              _contactsKey.currentState?.reloadCredentials();
            }
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
              icon: Icon(Icons.contacts_outlined),
              selectedIcon: Icon(Icons.contacts_rounded, color: Color(0xFFFF8C00)),
              label: 'Contacts',
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