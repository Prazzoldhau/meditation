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

  final _tracks = <MeditationTrack>[];
  final _scroll = ScrollController();

  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _bundledFallback = false;
  bool _firstLoadDone = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 500;
    if (nearBottom) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    // Show the footer spinner. The first call comes straight from initState
    // (tracks empty) - the imminent first build already reflects _loading, so
    // no setState is wanted yet.
    if (_firstLoadDone) setState(() {});

    try {
      final List<MeditationTrack> fetched;
      var hasMore = false;
      var nextOffset = _offset;

      if (SupabaseConfig.canBrowse && !_bundledFallback) {
        final page = await _service.fetchPage(offset: _offset);
        fetched = page.tracks;
        hasMore = page.hasMore;
        nextOffset = page.nextOffset;
      } else {
        _bundledFallback = true;
        fetched = await _service.fetchBundled();
      }

      if (!mounted) return;
      setState(() {
        if (_bundledFallback) _tracks.clear();
        _tracks.addAll(fetched);
        _offset = nextOffset;
        _hasMore = hasMore;
        _loading = false;
        _firstLoadDone = true;
      });
    } catch (e) {
      // Live browse failed - fall back to the bundled snapshot once.
      if (_tracks.isEmpty && !_bundledFallback) {
        try {
          final bundled = await _service.fetchBundled();
          if (!mounted) return;
          setState(() {
            _tracks
              ..clear()
              ..addAll(bundled);
            _bundledFallback = true;
            _hasMore = false;
            _loading = false;
            _firstLoadDone = true;
          });
          return;
        } catch (_) {/* show the original error below */}
      }
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _firstLoadDone = true;
      });
    }
  }

  Future<void> _refresh() async {
    // Fetch a fresh first page without tearing down the current list; swap on
    // success so pull-to-refresh doesn't flash an empty screen.
    try {
      final List<MeditationTrack> fresh;
      var hasMore = false;
      var nextOffset = 0;
      final useBundled = !SupabaseConfig.canBrowse || _bundledFallback;

      if (useBundled) {
        fresh = await _service.fetchBundled();
      } else {
        final page = await _service.fetchPage(offset: 0);
        fresh = page.tracks;
        hasMore = page.hasMore;
        nextOffset = page.nextOffset;
      }

      if (!mounted) return;
      setState(() {
        _tracks
          ..clear()
          ..addAll(fresh);
        _offset = nextOffset;
        _hasMore = hasMore;
        _bundledFallback = useBundled;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tracks.isEmpty && _loading) {
      return const BrandedLoader(message: 'Loading meditations…');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Osho Meditation'),
        bottom: _bundledFallback
            ? PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Offline list',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              )
            : null,
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_tracks.isEmpty && _error != null) {
      return _ErrorView(error: _error!, onRetry: _loadMore);
    }
    if (_tracks.isEmpty) {
      return const Center(child: Text('No meditations found yet.'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _tracks.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _tracks.length) return _footer(context);
          final track = _tracks[index];
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

  Widget _footer(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Could not load more.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(onPressed: _loadMore, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_hasMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '${_tracks.length} meditations',
          style: Theme.of(context).textTheme.labelMedium,
        ),
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
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
