# Osho Meditation

Flutter app that streams the guided-meditation MP3s from the **public**
Supabase Storage bucket **`es dhammo sanatano`** (project `qrdpstvibstonmwlmhbu`).

Because the bucket is public, the app needs **no API key, no sign-in, no
`--dart-define`** — it just plays each object's public URL. The track list
lives in [`assets/tracks.json`](assets/tracks.json) (bundled with the app), so
there's also no bucket-listing call at runtime.

This project was hand-written (no local Flutter SDK). The **`android/` folder
is committed** (same approach as the qr_scanner app) so a build only needs
`flutter pub get` → `flutter build apk`. The **`ios/` folder is not** committed
— the iOS workflow regenerates it with `flutter create` on the build machine
(`.metadata` tells `flutter create` this is an `app` targeting android + ios).

## Wiring the build into Codemagic

**Android** — either mode works out of the box:

- **`codemagic.yaml` mode**: nothing to do, the `android-workflow` runs
  `pub get` → `dart run flutter_launcher_icons` → `flutter build apk`.
- **Codemagic UI (Workflow Editor) mode**: set **Workflow → Build →
  "Pre-build script"** to exactly `bash scripts/codemagic_pre_build.sh`
  (or just clear it — the committed `android/` folder is enough). No
  `--dart-define` build args are needed any more.

**iOS**: needs code signing configured in Codemagic first; the `ios-workflow`
in `codemagic.yaml` regenerates `ios/` via `scripts/codemagic_pre_build.sh`.

## How it works

- [`assets/tracks.json`](assets/tracks.json) holds `baseUrl` +  a list of
  tracks. Each track's `files` array is one or more object names; a track with
  two files (e.g. `… 61_part1.mp3` + `… 61_part2.mp3`) plays them back-to-back
  as one meditation.
- `lib/services/meditation_service.dart` loads that JSON and builds the
  URL-encoded public links (`<baseUrl>/<Uri.encodeComponent(file)>`).
- `lib/screens/player_screen.dart` plays a track with `just_audio` — a single
  `AudioSource.uri` for one file, a `ConcatenatingAudioSource` for multi-part,
  with a "Part n of m" indicator and skip buttons.

### Adding / removing meditations

Edit `assets/tracks.json` and rebuild. Example entries:

```json
{ "title": "Es Dhammo Sanantano 42", "files": ["Es Dhammo Sanantano 42.MP3"] },
{ "title": "Es Dhammo Sanantano 61", "files": ["Es Dhammo Sanantano 61_part1.mp3", "Es Dhammo Sanantano 61_part2.mp3"] }
```

`files` are the raw object names in the bucket (spaces and all) — the app
URL-encodes them. If you ever make the bucket private, this approach stops
working and you'd need to add `supabase_flutter` back for signed URLs.

## Local development (once you have Flutter installed somewhere)

```
# android/ is already in the repo; add ios/ only if you need it:
# flutter create . --platforms=ios --org com.oshomeditation --project-name osho_meditation
flutter pub get
flutter run
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
first frame, then `HomeScreen` shows the same logo on white (`BrandedLoader`,
`assets/branding/osho_logo_transparent.png`) while `tracks.json` loads. One
continuous loading state.

To change the icon/splash: replace the source PNGs in `assets/branding/`
(keep the filenames), then regenerate the `android/` resources — run
`dart run flutter_launcher_icons` for the icon; the splash PNGs are plain
centred exports of the logo at mdpi–xxxhdpi (150/225/300/450/600 px wide).

## Customizing

- **App/package name**: `applicationId` + `namespace` in
  `android/app/build.gradle`, the `package` in `MainActivity.kt` (and its
  folder path), `android:label` in `android/app/src/main/AndroidManifest.xml`,
  and `pubspec.yaml`'s `name:`.
- **Track list / bucket URL**: [`assets/tracks.json`](assets/tracks.json).
- **Icon / splash artwork**: `assets/branding/` (see above).
