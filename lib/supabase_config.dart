/// Connection details for the public Supabase Storage bucket.
///
/// The `anon` key is a *public* key - it is designed to ship inside client
/// apps, and the bucket's data is protected by Storage RLS policies, not by
/// keeping this string secret. It is only needed to *list* the bucket
/// (browsing); playing an individual file needs no key at all.
///
/// Override at build time if you prefer not to commit it:
///   flutter build apk --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const String projectUrl = 'https://qrdpstvibstonmwlmhbu.supabase.co';
  static const String bucket = 'es dhammo sanatano';

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // <-- paste the anon public key here to enable browsing
  );

  /// True when we have a key and can call the Storage list API.
  static bool get canBrowse => anonKey.isNotEmpty;

  static String publicUrlFor(String objectName) =>
      '$projectUrl/storage/v1/object/public/'
      '${Uri.encodeComponent(bucket)}/${Uri.encodeComponent(objectName)}';

  static Uri get listEndpoint => Uri.parse(
        '$projectUrl/storage/v1/object/list/${Uri.encodeComponent(bucket)}',
      );
}
