/// A single audio track in a list (meditation or background sound).
///
/// [urls] holds one or more fully-qualified links to the audio files. When
/// browsing a bucket live, each object is its own track (one url); the
/// bundled fallback list can also group `_part1` / `_part2` files into one
/// track (multiple urls).
///
/// [headers] is set when the bucket isn't public - the URLs point at
/// Supabase's *authenticated* object endpoint and need the `apikey` /
/// `Authorization` headers on every request (including range requests while
/// seeking).
class MeditationTrack {
  const MeditationTrack({
    required this.title,
    required this.urls,
    this.fileName,
    this.headers,
  });

  final String title;
  final List<String> urls;

  /// Raw object name in the bucket, when known (live-browsed tracks).
  final String? fileName;

  final Map<String, String>? headers;

  bool get isMultiPart => urls.length > 1;
  int get partCount => urls.length;
}
