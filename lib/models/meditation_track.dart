/// A single meditation audio file living in the Supabase Storage bucket.
class MeditationTrack {
  MeditationTrack({required this.fileName});

  /// Raw object name/path as stored in the bucket, e.g. "01 - intro.mp3".
  final String fileName;

  /// Human-friendly title derived from the file name.
  String get title {
    final withoutExtension = fileName.replaceAll(
      RegExp(r'\.mp3$', caseSensitive: false),
      '',
    );
    return withoutExtension.replaceAll('_', ' ').trim();
  }
}
