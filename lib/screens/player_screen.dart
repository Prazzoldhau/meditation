import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/meditation_track.dart';
import '../services/meditation_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.track,
    required this.service,
  });

  final MeditationTrack track;
  final MeditationService service;

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
      final url = await widget.service.getPlaybackUrl(widget.track.fileName);
      await _player.setUrl(url);
      await _player.play();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this track: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.self_improvement,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        StreamBuilder<Duration?>(
                          stream: _player.durationStream,
                          builder: (context, durationSnap) {
                            final duration = durationSnap.data ?? Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: _player.positionStream,
                              builder: (context, positionSnap) {
                                var position = positionSnap.data ?? Duration.zero;
                                if (position > duration) position = duration;
                                return Column(
                                  children: [
                                    Slider(
                                      min: 0,
                                      max: duration.inMilliseconds.toDouble().clamp(
                                            0,
                                            double.infinity,
                                          ),
                                      value: position.inMilliseconds
                                          .toDouble()
                                          .clamp(0, duration.inMilliseconds.toDouble()),
                                      onChanged: duration.inMilliseconds == 0
                                          ? null
                                          : (value) {
                                              _player.seek(
                                                Duration(milliseconds: value.round()),
                                              );
                                            },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(_formatDuration(position)),
                                          Text(_formatDuration(duration)),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<PlayerState>(
                          stream: _player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton(
                              iconSize: 64,
                              icon: Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
                              onPressed: () {
                                playing ? _player.pause() : _player.play();
                              },
                            );
                          },
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
