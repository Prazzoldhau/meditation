import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/meditation_track.dart';

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

  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  void dispose() {
    _player.dispose();
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.self_improvement, size: 96, color: scheme.primary),
              const SizedBox(height: 24),
              if (widget.track.isMultiPart) _partIndicator(context),
              _progress(context),
              const SizedBox(height: 8),
              _controls(context),
              if (_error != null) _errorBar(context),
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
}
