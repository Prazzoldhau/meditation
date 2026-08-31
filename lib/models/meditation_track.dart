/// A single meditation in the list.
///
/// [urls] holds one or more fully-qualified, URL-encoded links to the audio
/// files in the public Supabase Storage bucket. Most tracks are a single
/// file; a few are split into `_part1` / `_part2` and play back-to-back as
/// one track.
class MeditationTrack {
  const MeditationTrack({required this.title, required this.urls});

  final String title;
  final List<String> urls;

  bool get isMultiPart => urls.length > 1;
  int get partCount => urls.length;
}
