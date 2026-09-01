import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wires up the Android foreground service + media-style notification, so a
  // meditation keeps playing (and can still buffer) with the screen locked or
  // the app in the background.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.oshomeditation.osho_meditation.audio',
    androidNotificationChannelName: 'Meditation playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
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
