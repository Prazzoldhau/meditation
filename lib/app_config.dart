/// Build-time configuration, injected via `--dart-define` so Supabase
/// credentials never get hardcoded or committed to git.
///
/// Local run example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://qrdpstvibstonmwlmhbu.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
///
/// On Codemagic, set SUPABASE_URL and SUPABASE_ANON_KEY as encrypted
/// environment variables (see codemagic.yaml) and they get passed through
/// automatically.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Name of the Supabase Storage bucket holding the meditation audio.
  static const String bucketName = 'es dhammo sanatano';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
