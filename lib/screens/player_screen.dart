import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/meditation_track.dart';
import '../services/meditation_service.dart';
import '../supabase_config.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.track});

  final MeditationTrack track;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Tuned so playback starts as soon as ~1s of audio is buffered, then keeps
  // filling in the background - like a YouTube video, not a full download.
  final _player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 15),
        maxBufferDuration: Duration(seconds: 45),
        bufferForPlaybackDuration: Duration(milliseconds: 1000),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 3),
      ),
      darwinLoadControl: DarwinLoadControl(
        automaticallyWaitsToMinimizeStalling: false,
        preferredForwardBufferDuration: Duration(seconds: 6),
      ),
    ),
  );

  // Second, independent player for a looping background sound. Deliberately a
  // plain AudioPlayer (no MediaItem tag) - just_audio_background drives the
  // notification/lock-screen session for a single player only; this one just
  // mixes in behind it and rides along on the same foreground service.
  //
  // handleInterruptions/handleAudioSessionActivation are OFF here: by default
  // every just_audio player fights for audio focus, and each one auto-pauses
  // when it "loses" focus to another - including another player in the same
  // app. With two players that means whichever plays second silently pauses
  // the first (or itself). Making _player the sole focus/session owner and
  // this one a passive renderer is what actually lets both play together.
  final _bgPlayer = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
  );

  String? _error;

  List<MeditationTrack> _softTracks = const [];
  bool _softLoading = true;
  String? _softError;
  int? _selectedSoft;

  double _mainVolume = 1;
  double _bgVolume = 0.5;
  double _lastMainVolume = 1;
  double _lastBgVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSoftTracks();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final urls = widget.track.urls;
      final sources = [
        for (var i = 0; i < urls.length; i++)
          AudioSource.uri(
            Uri.parse(urls[i]),
            // Required by just_audio_background - drives the lock-screen /
            // notification metadata.
            tag: MediaItem(
              id: urls[i],
              title: widget.track.title,
              artist: widget.track.isMultiPart
                  ? 'Osho Meditation · Part ${i + 1} of ${urls.length}'
                  : 'Osho Meditation',
            ),
          ),
      ];
      await _player.setAudioSource(
        sources.length == 1
            ? sources.first
            : ConcatenatingAudioSource(
                useLazyPreparation: true, // don't touch part 2 until near it
                children: sources,
              ),
        preload: true,
      );
      await _player.play();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _loadSoftTracks() async {
    if (!SupabaseConfig.canBrowse) {
      setState(() => _softLoading = false);
      return;
    }
    try {
      const service = MeditationService();
      // Not marked Public in Supabase - stream via the authenticated URL.
      final tracks = await service.fetchAll(
        SupabaseConfig.softMusicBucket,
        public: false,
      );
      if (!mounted) return;
      setState(() {
        _softTracks = tracks;
        _softLoading = false;
      });
      if (tracks.isNotEmpty) {
        await _selectSoft(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _softLoading = false;
        _softError = '$e';
      });
    }
  }

  Future<void> _selectSoft(int index) async {
    if (index < 0 || index >= _softTracks.length) return;
    setState(() {
      _selectedSoft = index;
      _softError = null;
    });
    try {
      final track = _softTracks[index];
      await _bgPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(track.urls.first),
          headers: track.headers,
          // just_audio_background's docs say it's built for a single tagged
          // player; give this source a tag too (distinct id prefix) in case
          // an untagged source on a second player is what's silently failing.
          tag: MediaItem(id: 'bg:${track.urls.first}', title: track.title),
        ),
      );
      await _bgPlayer.setLoopMode(LoopMode.one); // loop under the whole track
      await _bgPlayer.setVolume(_bgVolume);
      await _bgPlayer.play();
    } catch (e) {
      // Show the real error - so a failure is actually visible/reportable
      // instead of the chip list just quietly doing nothing.
      if (mounted) setState(() => _softError = '$e');
    }
  }

  Future<void> _clearSoft() async {
    setState(() => _selectedSoft = null);
    await _bgPlayer.stop();
  }

  void _setMainVolume(double v) {
    setState(() => _mainVolume = v);
    _player.setVolume(v);
    if (v > 0) _lastMainVolume = v;
  }

  void _toggleMainMute() =>
      _setMainVolume(_mainVolume > 0 ? 0 : _lastMainVolume);

  void _setBgVolume(double v) {
    setState(() => _bgVolume = v);
    _bgPlayer.setVolume(v);
    if (v > 0) _lastBgVolume = v;
  }

  void _toggleBgMute() => _setBgVolume(_bgVolume > 0 ? 0 : _lastBgVolume);

  @override
  void dispose() {
    _player.dispose();
    _bgPlayer.dispose();
    super.dispose();
  }

  void _seekBy(int seconds) {
    final duration = _player.duration;
    var target = _player.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (duration != null && target > duration) target = duration;
    _player.seek(target);
  }

  static String _fmt(Duration? d) {
    if (d == null) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.track.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.self_improvement, size: 88, color: scheme.primary),
              const SizedBox(height: 20),
              if (widget.track.isMultiPart) _partIndicator(context),
              _progress(context),
              const SizedBox(height: 8),
              _controls(context),
              if (_error != null) _errorBar(context),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _soundSelector(context),
              const SizedBox(height: 20),
              _volumeControls(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partIndicator(BuildContext context) {
    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, snap) {
        final part = (snap.data ?? 0) + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Part $part of ${widget.track.partCount}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        );
      },
    );
  }

  Widget _progress(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, durationSnap) {
        final duration = durationSnap.data;
        final maxMs = (duration?.inMilliseconds ?? 0).toDouble();
        final ready = maxMs > 0;

        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: _player.bufferedPositionStream,
              builder: (context, bufSnap) {
                final buffered = bufSnap.data ?? Duration.zero;
                final sliderMax = ready ? maxMs : 1.0;
                final posMs = position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, sliderMax)
                    .toDouble();
                final double bufFrac = ready
                    ? (buffered.inMilliseconds / maxMs).clamp(0.0, 1.0).toDouble()
                    : 0.0;

                return Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // YouTube-style "buffered ahead" bar behind the thumb
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: bufFrac,
                                minHeight: 4,
                                backgroundColor:
                                    scheme.onSurface.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation(
                                  scheme.primary.withValues(alpha: 0.30),
                                ),
                              ),
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              inactiveTrackColor: Colors.transparent,
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              min: 0,
                              max: sliderMax,
                              value: posMs,
                              onChanged: ready
                                  ? (v) => _player
                                      .seek(Duration(milliseconds: v.round()))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position)),
                          Text(_fmt(duration)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _controls(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.track.isMultiPart)
            IconButton(
              iconSize: 32,
              tooltip: 'Previous part',
              icon: const Icon(Icons.skip_previous),
              onPressed: () => _player.seekToPrevious(),
            ),
          IconButton(
            iconSize: 40,
            tooltip: 'Back 10 seconds',
            icon: const Icon(Icons.replay_10),
            onPressed: () => _seekBy(-10),
          ),
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final processing = state?.processingState;
              final busy = processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering;
              final playing = state?.playing ?? false;
              final ended = processing == ProcessingState.completed;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    iconSize: 64,
                    icon: Icon(
                      ended
                          ? Icons.replay_circle_filled
                          : playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                    ),
                    onPressed: () {
                      if (ended) {
                        _player.seek(Duration.zero, index: 0);
                        _player.play();
                      } else if (playing) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                  ),
                  // thin ring over the button while (re)buffering - playback
                  // controls stay usable underneath
                  if (busy)
                    const SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              );
            },
          ),
          IconButton(
            iconSize: 40,
            tooltip: 'Forward 10 seconds',
            icon: const Icon(Icons.forward_10),
            onPressed: () => _seekBy(10),
          ),
          if (widget.track.isMultiPart)
            IconButton(
              iconSize: 32,
              tooltip: 'Next part',
              icon: const Icon(Icons.skip_next),
              onPressed: () => _player.seekToNext(),
            ),
        ],
      ),
    );
  }

  Widget _errorBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            'Could not play this meditation.\n$_error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  // --- background sound: TikTok-style horizontal picker -------------------

  Widget _soundSelector(BuildContext context) {
    if (!SupabaseConfig.canBrowse) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Background sound',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        SizedBox(
          height: 86,
          child: _softLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_softTracks.isEmpty
                  ? Center(
                      child: Text(
                        _softError != null
                            ? 'Background sounds unavailable'
                            : 'No background sounds yet',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _softTracks.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _soundChip(
                            context,
                            label: 'None',
                            icon: Icons.music_off,
                            selected: _selectedSoft == null,
                            onTap: _clearSoft,
                          );
                        }
                        final idx = i - 1;
                        return _soundChip(
                          context,
                          label: _softTracks[idx].title,
                          icon: Icons.music_note,
                          selected: _selectedSoft == idx,
                          onTap: () => _selectSoft(idx),
                        );
                      },
                    )),
        ),
        // Visible even once tracks are loaded - a failure while actually
        // trying to play a selected sound landed here invisibly before.
        if (_softError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Background sound error: $_softError',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _soundChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: selected ? scheme.primary : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- independent volume sliders ------------------------------------------

  Widget _volumeControls(BuildContext context) {
    return Column(
      children: [
        _volumeRow(
          icon: Icons.self_improvement,
          volume: _mainVolume,
          onChanged: _setMainVolume,
          onMuteToggle: _toggleMainMute,
        ),
        const SizedBox(height: 2),
        _volumeRow(
          icon: Icons.music_note,
          volume: _bgVolume,
          onChanged: _setBgVolume,
          onMuteToggle: _toggleBgMute,
          leading: _bgPlayPauseButton(),
        ),
      ],
    );
  }

  /// Play/pause for the background sound only, independent of the meditation.
  Widget _bgPlayPauseButton() {
    return StreamBuilder<PlayerState>(
      stream: _bgPlayer.playerStateStream,
      builder: (context, snap) {
        final state = snap.data;
        final playing = state?.playing ?? false;
        final busy = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        final hasSource = _selectedSoft != null;
        return IconButton(
          tooltip: playing ? 'Pause background sound' : 'Play background sound',
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(playing ? Icons.pause_circle_outline : Icons.play_circle_outline),
          onPressed: !hasSource
              ? null
              : () => playing ? _bgPlayer.pause() : _bgPlayer.play(),
        );
      },
    );
  }

  Widget _volumeRow({
    required IconData icon,
    required double volume,
    required ValueChanged<double> onChanged,
    required VoidCallback onMuteToggle,
    Widget? leading,
  }) {
    return Row(
      children: [
        if (leading != null) leading,
        IconButton(
          icon: Icon(volume <= 0 ? Icons.volume_off : Icons.volume_up),
          onPressed: onMuteToggle,
        ),
        Icon(icon, size: 18),
        Expanded(
          child: Slider(
            value: volume,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${(volume * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
