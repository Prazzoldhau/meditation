# Osho Meditation

Flutter app that streams the guided-meditation MP3s from the Supabase
Storage bucket **`es dhammo sanatano`** (project `qrdpstvibstonmwlmhbu`).

This project was hand-written (no local Flutter SDK). The **`android/` folder
is committed** (same approach as the qr_scanner app) so a build only needs
`flutter pub get` → `flutter build apk`. The **`ios/` folder is not** committed
— the iOS workflow regenerates it with `flutter create` on the build machine
(`.metadata` tells `flutter create` this is an `app` targeting android + ios).

### Wiring the build into Codemagic

**Android** — either mode works out of the box:

- **`codemagic.yaml` mode**: nothing to do, the `android-workflow` runs
  `pub get` → `dart run flutter_launcher_icons` → `flutter build apk`.
- **Codemagic UI (Workflow Editor) mode**: set **Workflow → Build →
  "Pre-build script"** to exactly:

  ```
  bash scripts/codemagic_pre_build.sh
  ```

  (Remove any older content — earlier drafts referenced
  `flutter_native_splash`, which is no longer a dependency and would fail
  with "package not found".)

**iOS**: needs code signing configured in Codemagic first; the `ios-workflow`
in `codemagic.yaml` regenerates `ios/` via `scripts/codemagic_pre_build.sh`.

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
# android/ is already in the repo; add ios/ only if you need it:
# flutter create . --platforms=ios --org com.oshomeditation --project-name osho_meditation
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://qrdpstvibstonmwlmhbu.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## App icon & splash screen

The OSHO logo drives the launcher icon and the startup splash. Both are
**baked into the committed `android/` folder** (generated from
`assets/branding/` with Pillow), so they work with no build-time step. CI also
re-runs `dart run flutter_launcher_icons`, which just rewrites the same files.

| Android resource | Source art | Role |
| --- | --- | --- |
| `mipmap-*/ic_launcher.png` | `osho_logo.png` | legacy square icon (pre-API 26) |
| `mipmap-*/ic_launcher_foreground.png` | `icon_foreground.png` | adaptive icon **foreground** (padded logo) |
| `mipmap-*/ic_launcher_background.png` | `icon_background.png` | adaptive icon **background** (faded logo watermark) |
| `mipmap-anydpi-v26/ic_launcher.xml` | — | ties the two adaptive layers together |
| `drawable-*/splash_logo.png` | `osho_logo_transparent.png` | centred logo on the native launch screen |
| `drawable*/launch_background.xml` | — | white background + `splash_logo`, centred |

The native launch screen (white + logo) stays up until `runApp()` paints the
first frame — which is after `Supabase.initialize()` — then `HomeScreen` shows
the same logo on white (`BrandedLoader`, `assets/branding/osho_logo_transparent.png`)
during the first track fetch. One continuous loading state, no extra package.

To change the icon/splash: replace the source PNGs in `assets/branding/`
(keep the filenames), then regenerate the `android/` resources — run
`dart run flutter_launcher_icons` for the icon; the splash PNGs are plain
centred exports of the logo at mdpi–xxxhdpi (150/225/300/450/600 px wide).

## Customizing

- **App/package name**: `applicationId` + `namespace` in
  `android/app/build.gradle`, the `package` in `MainActivity.kt` (and its
  folder path), `android:label` in `android/app/src/main/AndroidManifest.xml`,
  and `pubspec.yaml`'s `name:`.
- **Bucket name**: `AppConfig.bucketName` in `lib/app_config.dart`.
- **Signed URL lifetime**: `_signedUrlExpirySeconds` in
  `lib/services/meditation_service.dart` (defaults to 1 hour).
- **Icon / splash artwork**: `assets/branding/` (see above).
