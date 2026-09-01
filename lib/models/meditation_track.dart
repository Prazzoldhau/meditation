/// A single meditation in the list.
///
/// [urls] holds one or more fully-qualified, URL-encoded links to the audio
/// files in the public Supabase Storage bucket. When browsing the bucket live
/// each object is its own track (one url); the bundled fallback list can also
/// group `_part1` / `_part2` files into one track (multiple urls).
class MeditationTrack {
  const MeditationTrack({
    required this.title,
    required this.urls,
    this.fileName,
  });

  final String title;
  final List<String> urls;

  /// Raw object name in the bucket, when known (live-browsed tracks).
  final String? fileName;

  bool get isMultiPart => urls.length > 1;
  int get partCount => urls.length;
}
