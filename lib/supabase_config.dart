/// Connection details for the public Supabase Storage buckets.
///
/// The `anon` key is a *public* key - it is designed to ship inside client
/// apps, and the bucket's data is protected by Storage RLS policies, not by
/// keeping this string secret. It is only needed to *list* a bucket
/// (browsing); playing an individual file needs no key at all.
///
/// Override at build time if you prefer not to commit it:
///   flutter build apk --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const String projectUrl = 'https://qrdpstvibstonmwlmhbu.supabase.co';

  /// The guided-meditation recordings.
  static const String meditationBucket = 'es dhammo sanatano';

  /// Looping background/ambient tracks played alongside a meditation.
  static const String softMusicBucket = 'soft music';

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // anon / public key - safe to ship (RLS on storage.objects protects data).
    // A --dart-define of the same name overrides this at build time.
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFyZHBzdHZpYnN0b25td2xtaGJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMjQ3MTEsImV4cCI6MjEwMzcwMDcxMX0.1CixKOjnRG9sQrNsy4QCKcUU8mE6nUoxcx7nGgJ1KvQ',
  );

  /// True when we have a key and can call the Storage list API.
  static bool get canBrowse => anonKey.isNotEmpty;

  /// For a bucket marked *Public* in Supabase - plain URL, no headers needed.
  static String publicUrlFor(String bucket, String objectName) =>
      '$projectUrl/storage/v1/object/public/'
      '${Uri.encodeComponent(bucket)}/${Uri.encodeComponent(objectName)}';

  /// For a *private* bucket - same `anon` SELECT policy that allows listing
  /// also allows this authenticated download URL, as long as [authHeaders]
  /// are sent with every request (see `MeditationTrack.headers`).
  static String authenticatedUrlFor(String bucket, String objectName) =>
      '$projectUrl/storage/v1/object/'
      '${Uri.encodeComponent(bucket)}/${Uri.encodeComponent(objectName)}';

  static Map<String, String> get authHeaders => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
      };

  static Uri listEndpoint(String bucket) => Uri.parse(
        '$projectUrl/storage/v1/object/list/${Uri.encodeComponent(bucket)}',
      );

  /// A short-lived, header-free download URL for a private bucket - the
  /// token lives in the query string, so any player that can't send custom
  /// headers (e.g. `audioplayers`) can still stream it directly.
  static Uri signEndpoint(String bucket, String objectName) => Uri.parse(
        '$projectUrl/storage/v1/object/sign/'
        '${Uri.encodeComponent(bucket)}/${Uri.encodeComponent(objectName)}',
      );
}
