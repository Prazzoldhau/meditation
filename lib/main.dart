import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the native splash (logo screen) on screen through app startup so
  // there's no blank flash while the engine and Supabase warm up.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  if (!AppConfig.isConfigured) {
    FlutterNativeSplash.remove();
    runApp(const _MissingConfigApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } finally {
    FlutterNativeSplash.remove();
  }

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
