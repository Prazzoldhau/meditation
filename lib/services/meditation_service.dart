import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/meditation_track.dart';
import '../supabase_config.dart';

/// One page of browsed tracks plus the cursor for the next page.
class TrackPage {
  const TrackPage({
    required this.tracks,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<MeditationTrack> tracks;
  final int nextOffset;
  final bool hasMore;
}

/// Loads the meditation list.
///
/// Primary path: page through the live bucket via the Storage `list` API
/// (needs [SupabaseConfig.anonKey]). Fallback: the bundled `assets/tracks.json`
/// snapshot, loaded in one shot.
class MeditationService {
  const MeditationService();

  static const String _manifestAsset = 'assets/tracks.json';
  static const int pageSize = 40;

  static final RegExp _audio = RegExp(r'\.mp3$', caseSensitive: false);

  /// Fetches one page of objects from the bucket, sorted by name.
  Future<TrackPage> fetchPage({required int offset, int limit = pageSize}) async {
    final res = await http.post(
      SupabaseConfig.listEndpoint,
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      },
      body: jsonEncode({
        'prefix': '',
        'limit': limit,
        'offset': offset,
        'sortBy': {'column': 'name', 'order': 'asc'},
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Storage list failed (${res.statusCode}). '
        '${res.body}',
      );
    }

    final raw = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    final tracks = <MeditationTrack>[];
    for (final obj in raw) {
      final name = obj['name'] as String? ?? '';
      // Skip folders / placeholders and non-audio files.
      if (obj['id'] == null) continue;
      if (!_audio.hasMatch(name)) continue;
      tracks.add(
        MeditationTrack(
          title: _titleFor(name),
          urls: [SupabaseConfig.publicUrlFor(name)],
          fileName: name,
        ),
      );
    }

    return TrackPage(
      tracks: tracks,
      nextOffset: offset + raw.length,
      hasMore: raw.length == limit,
    );
  }

  /// The bundled snapshot - every track at once. Used when there's no anon key
  /// or the live list call fails.
  Future<List<MeditationTrack>> fetchBundled() async {
    final data =
        jsonDecode(await rootBundle.loadString(_manifestAsset)) as Map<String, dynamic>;
    final base = (data['baseUrl'] as String).replaceAll(RegExp(r'/+$'), '');
    final entries = (data['tracks'] as List).cast<Map<String, dynamic>>();

    return entries.map((entry) {
      final files = (entry['files'] as List).cast<String>();
      return MeditationTrack(
        title: entry['title'] as String,
        urls: [for (final f in files) '$base/${Uri.encodeComponent(f)}'],
      );
    }).toList(growable: false);
  }

  static String _titleFor(String objectName) =>
      objectName.replaceAll(_audio, '').trim();
}
