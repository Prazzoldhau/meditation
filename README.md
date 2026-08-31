# Osho Meditation

Flutter app that streams the guided-meditation MP3s from the Supabase
Storage bucket **`es dhammo sanatano`** (project `qrdpstvibstonmwlmhbu`).

This project was hand-written (no local Flutter SDK) so it can be built
entirely on Codemagic. The `android/` and `ios/` native folders are **not**
committed — `codemagic.yaml` runs `flutter create .` on the build machine to
generate them fresh before every build. That's normal for this setup, not a
missing piece.

`.metadata` **is** committed even though the platform folders aren't: it's the
file `flutter create` reads to know this is an `app` project targeting
`android` + `ios`, so the recreate run actually regenerates those folders
(without it, `flutter create .` only touches root files and the native
folders never appear).

## How it works

- `lib/services/meditation_service.dart` lists every `.mp3` object in the
  bucket via the Supabase Storage API, then creates a short-lived **signed
  URL** per track to actually stream it (works whether the bucket is public
  or private).
- No database table is required for the MVP — the file list *is* the track
  list, titled from the filename. If you later want richer metadata
  (categories, descriptions, artwork, ordering), add a Postgres table and
  swap `fetchTracks()` to query it instead.
- Supabase credentials are never hardcoded. They're read at build time via
  `String.fromEnvironment` in `lib/app_config.dart`, passed in with
  `--dart-define`.

## One-time setup

1. **Get your Supabase anon key**: Dashboard → this project → Project
   Settings → API → `anon` `public` key. (Use the anon key, not
   `service_role` — this key ships inside the compiled app.)
2. **Push this folder to a git repo** (GitHub/GitLab/Bitbucket) — Codemagic
   builds from a connected repo.
3. **In Codemagic**: add the app, then under Team settings → Environment
   variables, create a group named `supabase` containing:
   - `SUPABASE_URL` = `https://qrdpstvibstonmwlmhbu.supabase.co`
   - `SUPABASE_ANON_KEY` = your anon key (mark it "Secure")
4. Make sure the bucket's Storage RLS policies allow `SELECT` for the
   `anon` role (or whatever role your users authenticate as) — otherwise
   `fetchTracks()`/`createSignedUrl()` will fail with a permission error.
5. Run the **android-workflow** to get an APK. The **ios-workflow** additionally
   needs iOS code signing configured in Codemagic (App Store Connect
   integration) before it will succeed — skip it until you're ready for iOS.

## Local development (once you have Flutter installed somewhere)

```
flutter create . --platforms=android,ios --org com.oshomeditation --project-name osho_meditation
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://qrdpstvibstonmwlmhbu.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## App icon & splash screen

The OSHO logo (`assets/branding/`) drives both the launcher icon and the
startup splash. Because the native `android/` and `ios/` folders aren't in
git, the icon and splash resources can't be pre-generated — instead
`codemagic.yaml` runs the generators on the build machine, right after
`flutter create .` and `flutter pub get`:

```
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

Config lives in `pubspec.yaml` under `flutter_launcher_icons:` and
`flutter_native_splash:`. Source artwork:

| File | Used as |
| --- | --- |
| `osho_logo.png` | iOS icon + legacy Android icon |
| `icon_foreground.png` | adaptive-icon **foreground** + Android 12 splash icon |
| `icon_background.png` | adaptive-icon **background** (faded logo watermark) |
| `splash.png` | splash **foreground** (centred logo) |
| `splash_background.png` | splash **background** (faded full-bleed logo) |
| `osho_logo_transparent.png` | in-app loading screen (`BrandedLoader`) |

`main.dart` calls `FlutterNativeSplash.preserve` / `remove` so the splash
stays up until `Supabase.initialize()` finishes, then `HomeScreen` shows the
same logo (`BrandedLoader`) during the first track fetch — one continuous
loading state from cold start to content.

To regenerate the artwork from a new source image, edit
`assets/branding/*.png` (keep the same filenames and roughly the same
padding) and rebuild.

## Customizing

- **App/package name**: change `--org`/`--project-name` in `codemagic.yaml`
  and `pubspec.yaml`'s `name:` together.
- **Bucket name**: `AppConfig.bucketName` in `lib/app_config.dart`.
- **Signed URL lifetime**: `_signedUrlExpirySeconds` in
  `lib/services/meditation_service.dart` (defaults to 1 hour).
- **Icon / splash artwork**: `assets/branding/` (see above).
