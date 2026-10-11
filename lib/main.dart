import 'package:flutter/material.dart';
import 'views/main_tab_container.dart';

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