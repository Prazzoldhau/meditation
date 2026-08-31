import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../models/meditation_track.dart';

/// Talks to the Supabase Storage bucket that holds the meditation audio.
class MeditationService {
  MeditationService(this._client);

  final SupabaseClient _client;

  /// How long a signed playback URL stays valid.
  static const int _signedUrlExpirySeconds = 60 * 60; // 1 hour

  /// Lists every .mp3 in the bucket, sorted by name.
  Future<List<MeditationTrack>> fetchTracks() async {
    final objects =
        await _client.storage.from(AppConfig.bucketName).list();

    final tracks = objects
        .where((o) => o.name.toLowerCase().endsWith('.mp3'))
        .map((o) => MeditationTrack(fileName: o.name))
        .toList()
      ..sort((a, b) => a.fileName.compareTo(b.fileName));

    return tracks;
  }

  /// Returns a short-lived signed URL to actually stream/play [fileName].
  ///
  /// Signed URLs work whether the bucket is public or private, so this is
  /// the safest default regardless of how the bucket's access is configured
  /// in the Supabase dashboard.
  Future<String> getPlaybackUrl(String fileName) {
    return _client.storage
        .from(AppConfig.bucketName)
        .createSignedUrl(fileName, _signedUrlExpirySeconds);
  }
}
