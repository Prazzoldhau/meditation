import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const OshoMeditationApp());
}

class OshoMeditationApp extends StatelessWidget {
  const OshoMeditationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osho Meditation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB5651D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF120C08),
      ),
      home: const HomeScreen(),
    );
  }
}
