import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/meditation_track.dart';
import '../supabase_config.dart';

/// Loads audio track lists from Supabase Storage.
///
/// Primary path: [fetchAll] browses a live bucket via the Storage `list`
/// API (needs [SupabaseConfig.anonKey] + a `select` policy for `anon`),
/// paging through the object names, then sorts them numerically and merges
/// `_part1` / `_part2` files into one track.
///
/// Fallback (meditation bucket only): the bundled `assets/tracks.json`
/// snapshot.
class MeditationService {
  const MeditationService();

  static const String _manifestAsset = 'assets/tracks.json';
  static const int _apiPageSize = 100;

  static final RegExp _audio = RegExp(r'\.mp3$', caseSensitive: false);
  static final RegExp _partSuffix = RegExp(r'_part\d+$', caseSensitive: false);
  static final RegExp _trailingNumber = RegExp(r'(\d+)\s*$');

  /// Every audio object in [bucket], numerically ordered, multi-part merged.
  Future<List<MeditationTrack>> fetchAll(String bucket) async {
    final names = <String>[];
    var offset = 0;

    while (true) {
      final res = await http.post(
        SupabaseConfig.listEndpoint(bucket),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'prefix': '',
          'limit': _apiPageSize,
          'offset': offset,
          'sortBy': {'column': 'name', 'order': 'asc'},
        }),
      );
      if (res.statusCode != 200) {
        throw Exception('Storage list failed (${res.statusCode}). ${res.body}');
      }

      final raw = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      for (final obj in raw) {
        final name = obj['name'] as String? ?? '';
        if (obj['id'] == null) continue; // folder / placeholder
        if (_audio.hasMatch(name)) names.add(name);
      }

      if (raw.length < _apiPageSize) break;
      offset += raw.length;
      if (offset > 20000) break; // hard safety stop
    }

    return _group(bucket, names);
  }

  /// The bundled meditation snapshot - used when there's no anon key or the
  /// live call fails.
  Future<List<MeditationTrack>> fetchBundled() async {
    final data = jsonDecode(await rootBundle.loadString(_manifestAsset))
        as Map<String, dynamic>;
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

  // --- helpers -------------------------------------------------------------

  List<MeditationTrack> _group(String bucket, List<String> names) {
    final byBase = <String, List<String>>{};
    for (final name in names) {
      byBase.putIfAbsent(_baseName(name), () => <String>[]).add(name);
    }

    final tracks = byBase.values.map((files) {
      files.sort();
      return MeditationTrack(
        title: _titleFor(files.first),
        urls: [for (final f in files) SupabaseConfig.publicUrlFor(bucket, f)],
        fileName: files.length == 1 ? files.first : null,
      );
    }).toList();

    tracks.sort((a, b) {
      final na = _numberIn(a.title);
      final nb = _numberIn(b.title);
      if (na != nb) return na.compareTo(nb);
      return a.title.compareTo(b.title);
    });
    return tracks;
  }

  /// "Es Dhammo Sanantano 61_part2.mp3" -> "Es Dhammo Sanantano 61"
  static String _baseName(String objectName) =>
      objectName.replaceAll(_audio, '').replaceAll(_partSuffix, '').trim();

  /// "Es Dhammo Sanantano 61_part2.mp3" -> "Es Dhammo Sanantano 61"
  static String _titleFor(String objectName) => _baseName(objectName);

  static int _numberIn(String s) {
    final m = _trailingNumber.firstMatch(s);
    return m == null ? 1 << 30 : int.parse(m.group(1)!);
  }
}
