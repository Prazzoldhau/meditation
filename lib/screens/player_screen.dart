import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/meditation_track.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.track});

  final MeditationTrack track;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = AudioPlayer();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = [
        for (final url in widget.track.urls) AudioSource.uri(Uri.parse(url)),
      ];
      await _player.setAudioSource(
        sources.length == 1
            ? sources.first
            : ConcatenatingAudioSource(children: sources),
      );
      await _player.play();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this meditation:\n$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.track.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : _buildPlayer(context),
        ),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.self_improvement, size: 96, color: scheme.primary),
        const SizedBox(height: 24),

        if (widget.track.isMultiPart)
          StreamBuilder<int?>(
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
          ),

        StreamBuilder<Duration?>(
          stream: _player.durationStream,
          builder: (context, durationSnap) {
            final duration = durationSnap.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, positionSnap) {
                var position = positionSnap.data ?? Duration.zero;
                if (position > duration) position = duration;
                final maxMs = duration.inMilliseconds.toDouble();
                return Column(
                  children: [
                    Slider(
                      min: 0,
                      max: maxMs <= 0 ? 1 : maxMs,
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0, maxMs <= 0 ? 1 : maxMs),
                      onChanged: maxMs <= 0
                          ? null
                          : (v) => _player.seek(
                                Duration(milliseconds: v.round()),
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
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.track.isMultiPart)
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_previous),
                onPressed: () => _player.seekToPrevious(),
              ),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final processing = state?.processingState;
                if (processing == ProcessingState.loading ||
                    processing == ProcessingState.buffering) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  );
                }
                final playing = state?.playing ?? false;
                final ended = processing == ProcessingState.completed;
                return IconButton(
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
                );
              },
            ),
            if (widget.track.isMultiPart)
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_next),
                onPressed: () => _player.seekToNext(),
              ),
          ],
        ),
      ],
    );
  }
}
