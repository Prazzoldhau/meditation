import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

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

/// Shown instead of a blank/crashing app when SUPABASE_URL / SUPABASE_ANON_KEY
/// were not passed in via --dart-define at build time.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing Supabase configuration.\n\n'
              'Build with:\n'
              '--dart-define=SUPABASE_URL=...\n'
              '--dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
