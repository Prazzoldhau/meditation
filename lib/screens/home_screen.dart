import 'package:flutter/material.dart';

import '../models/meditation_track.dart';
import '../services/meditation_service.dart';
import '../supabase_config.dart';
import '../widgets/branded_loader.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _service = MeditationService();

  late Future<List<MeditationTrack>> _future;
  bool _bundledFallback = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MeditationTrack>> _load() async {
    if (SupabaseConfig.canBrowse) {
      try {
        final live = await _service.fetchAll();
        if (live.isNotEmpty) {
          _bundledFallback = false;
          return live;
        }
        // Empty usually means the `anon` SELECT policy is missing.
      } catch (_) {
        // fall through to the bundled snapshot
      }
    }
    _bundledFallback = true;
    return _service.fetchBundled();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MeditationTrack>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const BrandedLoader(message: 'Loading meditations…');
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Osho Meditation'),
            bottom: _bundledFallback
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(20),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Text(
                        'Offline list',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                : null,
          ),
          body: _body(context, snapshot),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncSnapshot<List<MeditationTrack>> snapshot,
  ) {
    if (snapshot.hasError) {
      return _ErrorView(
        error: snapshot.error!,
        onRetry: () => setState(() => _future = _load()),
      );
    }

    final tracks = snapshot.data ?? const <MeditationTrack>[];
    if (tracks.isEmpty) {
      return const Center(child: Text('No meditations found yet.'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tracks.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == tracks.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '${tracks.length} meditations',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            );
          }
          final track = tracks[index];
          return ListTile(
            leading: const Icon(Icons.self_improvement),
            title: Text(track.title),
            subtitle:
                track.isMultiPart ? Text('${track.partCount} parts') : null,
            trailing: const Icon(Icons.play_arrow),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load the meditation list:\n$error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
