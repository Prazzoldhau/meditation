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

### Track list — live from the bucket, with an offline fallback

- **Live** (preferred): `MeditationService.fetchAll()` pages through the
  Storage `list` API (100 at a time), collects the object names, sorts them
  numerically and merges `_part1` / `_part2` files into one track. So adding
  or removing files in the bucket just shows up in the app — no code change.
  The list renders lazily (`ListView.builder`); only ~128 filename records are
  fetched, never any audio up front.

  Needs `SupabaseConfig.anonKey` (committed in `lib/supabase_config.dart`, or
  `--dart-define=SUPABASE_ANON_KEY=…`) — a *public* key, safe to ship — **and**
  a Storage policy letting `anon` run `SELECT`:

  ```sql
  create policy "anon can list es dhammo sanatano"
  on storage.objects for select to anon
  using ( bucket_id = 'es dhammo sanatano' );
  ```

- **Offline fallback**: with no key, an empty result (missing policy) or any
  failure, the app loads the bundled [`assets/tracks.json`](assets/tracks.json)
  snapshot and shows an "Offline list" badge.

- `lib/services/meditation_service.dart` builds the URL-encoded public links
  (`<baseUrl>/<Uri.encodeComponent(file)>`) for both paths.
- `lib/screens/player_screen.dart` plays a track with `just_audio` — a single
  `AudioSource.uri` for one file, a `ConcatenatingAudioSource` for multi-part.
  Controls: 10-second back / forward, play/pause, and previous/next-part on
  multi-part tracks, plus a "Part n of m" indicator.

### Background sound (second bucket, played side by side)

A meditation can play alongside a looping ambient track from the
**`soft music`** bucket, each with its own volume slider - like TikTok's sound
picker, but two tracks mixed together instead of one replacing the other.

- A **second, independent `AudioPlayer`** (`_bgPlayer` in `player_screen.dart`)
  loads whichever sound is selected and loops it (`LoopMode.one`) for as long
  as the meditation plays. It deliberately carries no `MediaItem` tag -
  `just_audio_background` drives the lock-screen session for one player only
  (the meditation); the background player just mixes in behind it and stays
  alive on the same foreground service.
- `main.dart` configures one shared `AudioSession` (`audio_session` package,
  `.music()` preset). On top of that, `_bgPlayer` is constructed with
  `handleInterruptions: false, handleAudioSessionActivation: false` - by
  default *every* just_audio player requests audio focus and auto-pauses
  itself when it "loses" focus, including to another player in the same app,
  so two default-configured players silently pause each other. Turning that
  off on the background player makes the meditation player the sole
  focus/session owner while the background player just renders audio
  alongside it.
- The picker is a horizontal scroll of chips (`_soundSelector`) fed by
  `MeditationService.fetchAll(SupabaseConfig.softMusicBucket)` - same
  live-listing code as the meditation list, different bucket. Tapping a chip
  swaps `_bgPlayer`'s source without touching the meditation; "None" stops it.
- Two `Slider`s (`_volumeControls`) call `setVolume()` on each player
  independently, with a tap-to-mute icon that remembers the last level. The
  background row also has its own play/pause button (`_bgPlayPauseButton`),
  independent of the meditation's transport controls.

**Needs its own Storage policy** (the meditation bucket's policy doesn't cover
it):

```sql
create policy "anon can list soft music"
on storage.objects for select to anon
using ( bucket_id = 'soft music' );
```

Without it, the picker just shows "Background sounds unavailable" and the
meditation still plays normally on its own.

Unlike the meditation bucket, `soft music` is **not** marked Public in
Supabase - its public download URL 404s ("Bucket not found"). Rather than
requiring that dashboard change too, `MeditationService.fetchAll(bucket,
public: false)` builds the *authenticated* object URL instead
(`/object/{bucket}/{name}`, no `/public/`) and the resulting `MeditationTrack`
carries `SupabaseConfig.authHeaders` (`apikey` / `Authorization: Bearer`),
which `player_screen.dart` passes to `AudioSource.uri(..., headers: ...)`. The
same `select` policy above covers both listing and this authenticated
download.
- **Nothing is downloaded at startup** — only `tracks.json`. A track streams
  progressively when you open it (like a YouTube video): playback starts once
  ~1s is buffered (`AndroidLoadControl.bufferForPlaybackDuration`), the scrub
  bar shows immediately, and a lighter bar behind it shows how far ahead the
  buffer has filled. Multi-part tracks use `useLazyPreparation` so part 2 isn't
  touched until playback nears it.
- **Background playback**: `just_audio_background` runs a foreground service +
  media notification, so a meditation keeps playing (and buffering) with the
  screen locked or the app backgrounded, with lock-screen play/pause/seek.
  Setup: `JustAudioBackground.init()` in `main.dart`, the service/receiver +
  `FOREGROUND_SERVICE*` / `WAKE_LOCK` permissions in `AndroidManifest.xml`,
  the launcher activity switched to `AudioServiceActivity`, and every
  `AudioSource` carries a `MediaItem` tag. `just_audio_background` is pinned to
  `0.0.1-beta.15` (the release that matches `just_audio` 0.9.x).

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
