import 'package:flutter/material.dart';
import 'screens/screen1_home.dart';

void main() {
  runApp(const AneesApp());
}

class AneesApp extends StatelessWidget {
  const AneesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أنيس',
      // Forces RTL layout for the entire app (Arabic)
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
