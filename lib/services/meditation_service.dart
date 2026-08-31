import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/meditation_track.dart';

/// Loads the meditation list from the bundled `assets/tracks.json` and turns
/// each entry into ready-to-play public Storage URLs.
///
/// The bucket `es dhammo sanatano` is public, so no API key, sign-in or
/// signed URLs are needed - the object's public URL streams directly.
class MeditationService {
  const MeditationService();

  static const String _manifestAsset = 'assets/tracks.json';

  Future<List<MeditationTrack>> fetchTracks() async {
    final raw = await rootBundle.loadString(_manifestAsset);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final base = (data['baseUrl'] as String).replaceAll(RegExp(r'/+$'), '');
    final entries = (data['tracks'] as List).cast<Map<String, dynamic>>();

    return entries.map((entry) {
      final files = (entry['files'] as List).cast<String>();
      final urls = [
        for (final file in files) '$base/${Uri.encodeComponent(file)}',
      ];
      return MeditationTrack(title: entry['title'] as String, urls: urls);
    }).toList(growable: false);
  }
}
