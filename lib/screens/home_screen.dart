import 'package:flutter/material.dart';

import '../models/meditation_track.dart';
import '../services/meditation_service.dart';
import '../widgets/branded_loader.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _service = MeditationService();
  late Future<List<MeditationTrack>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _service.fetchTracks();
  }

  Future<void> _refresh() async {
    setState(() => _tracksFuture = _service.fetchTracks());
    await _tracksFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MeditationTrack>>(
      future: _tracksFuture,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        // First load (no data or error yet): no chrome, just the logo - a
        // continuation of the native splash so startup reads as one
        // uninterrupted loading state.
        if (waiting && !snapshot.hasData && !snapshot.hasError) {
          return const BrandedLoader(message: 'Loading meditations…');
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Osho Meditation')),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<MeditationTrack>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load the meditation list:\n${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final tracks = snapshot.data ?? const [];
    if (tracks.isEmpty) {
      return const Center(child: Text('No meditations found yet.'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final track = tracks[index];
          return ListTile(
            leading: const Icon(Icons.self_improvement),
            title: Text(track.title),
            subtitle: track.isMultiPart
                ? Text('${track.partCount} parts')
                : null,
            trailing: const Icon(Icons.play_arrow),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(track: track),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
