import 'package:flutter/material.dart';

import '../data/article.dart';
import '../data/news_repository.dart';
import '../data/time_utils.dart';
import 'tokens.dart';
import 'detail_screen.dart';
import 'widgets/article_card.dart';
import 'widgets/featured_card.dart';

/// The main feed screen: header, search, filter chips, featured card and
/// the scrolling list of articles. It owns all state: the loaded articles,
/// the search text, the active source filter, and the loading flag.
class NewsHome extends StatefulWidget {
  const NewsHome({super.key, required this.isDark, required this.onToggleTheme});

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<NewsHome> createState() => _NewsHomeState();
}

class _NewsHomeState extends State<NewsHome> {
  // Horizontal rhythm comes from tokens.dart (pageMargin) — same value
  // the cards use, so every edge lines up.
  final NewsRepository _repo = NewsRepository();
  final TextEditingController _searchController = TextEditingController();

  // Feed state.
  List<Article> _allArticles = const [];
  bool _loading = true;
  bool _usedFallback = false;

  // UI state.
  String _query = '';
  String? _sourceFilter; // null = "All"

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Controllers hold native resources (keyboard focus, listeners);
    // dispose them so nothing leaks when the screen goes away.
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final articles = await _repo.fetchArticles();
    // If this screen was removed from the tree while the request was in
    // flight (e.g. user quit the app), calling setState would crash.
    if (!mounted) return;
    setState(() {
      _allArticles = articles;
      _usedFallback = _repo.lastLoadUsedFallback;
      _loading = false;
    });
  }

  /// The source names that actually appear in the currently loaded feed,
  /// used to build the filter chips. Derived from data, so the chips never
  /// offer a filter that would show zero articles.
  List<String> get _availableSources {
    final names = _allArticles.map((a) => a.newsSite).toSet().toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.take(8).toList();
  }

  List<Article> get _visibleArticles {
    var list = _allArticles;
    if (_sourceFilter != null) {
      list = list.where((a) => a.newsSite == _sourceFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.newsSite.toLowerCase().contains(q) ||
              a.summary.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visibleArticles;

    return Scaffold(
      backgroundColor: scheme.surface,
      // RefreshIndicator gives the classic pull-to-refresh gesture on
      // mobile; Scrollbar keeps desktop/web scrolling visible.
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // The header is a plain sliver (not a SliverAppBar) so the
            // greeting sits a fixed 5dp below whatever the device's
            // status-bar inset is — SafeArea handles notches, punch-holes
            // and Dynamic Islands uniformly on every device. The theme
            // toggle lives inside the header row (see _Header).
            SliverToBoxAdapter(
              child: SafeArea(
                top: true,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _Header(
                    isDark: widget.isDark,
                    onToggleTheme: widget.onToggleTheme,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(pageMargin, 4, pageMargin, 0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search articles…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  // Filter chips: centered when they fit on screen,
                  // horizontally scrollable when they don't.
                  SizedBox(
                    height: 44,
                    // Centered when the chips fit, horizontally scrollable
                    // when they don't (see _ChipsRow).
                    child: _ChipsRow(
                      margin: pageMargin,
                      children: [
                        _sourceChip(null, 'All'),
                        for (final s in _availableSources) _sourceChip(s, s),
                      ],
                    ),
                  ),
                  if (_usedFallback && !_loading)
                    Padding(
                      padding: EdgeInsets.fromLTRB(pageMargin, 2, pageMargin, 6),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, size: 14, color: scheme.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Couldn\'t reach the API — showing offline articles.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // The feed body: skeleton while loading, then featured + list.
            if (_loading)
              const _ShimmerFeed()
            else ...[
              if (visible.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else ...[
                SliverToBoxAdapter(
                  child: FeaturedCard(
                    article: visible.first,
                    onTap: () => _open(visible.first),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pageMargin, 18, pageMargin, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _sourceFilter == null && _query.isEmpty
                          ? 'Latest'
                          : 'Results (${visible.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: visible.length - 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final article = visible[index + 1];
                    return ArticleCard(
                      article: article,
                      onTap: () => _open(article),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceChip(String? value, String label) {
    final selected = _sourceFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        showCheckmark: false,
        onSelected: (_) => setState(() {
          // Tapping the active chip deselects it — back to "All".
          _sourceFilter = selected ? null : value;
        }),
      ),
    );
  }

  void _open(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(article: article),
      ),
    );
  }
}

/// A horizontal chip row that centers itself when all chips fit within
/// the available width, and becomes a horizontally scrolling list when
/// they don't.
///
/// How it works, with no measuring needed: `SingleChildScrollView` sizes
/// itself to min(content, viewport) — smaller than the viewport when the
/// row fits, full width when it overflows. Wrapping it in `Center` then
/// centers it in exactly the "fits" case, and is a no-op when scrolling.
class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.children, required this.margin});

  final List<Widget> children;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin, vertical: 6),
        child: Row(children: children),
      ),
    );
  }
}


/// The greeting + date + theme toggle block that lives inside the
/// collapsing app bar. One Row keeps everything on the same baseline:
/// greeting/date on the left, the moon/sun icon right-aligned.
class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onToggleTheme});

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(pageMargin, 8, 12, 8),
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Expanded makes the text column take all width minus the icon,
          // so the icon hugs the right edge.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greetingFor(now),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  longDateFor(now),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pulsing placeholder cards shown while the feed loads. Hand-built
/// shimmer (no package): an animated gradient sweeping over grey boxes.
class _ShimmerFeed extends StatefulWidget {
  const _ShimmerFeed();

  @override
  State<_ShimmerFeed> createState() => _ShimmerFeedState();
}

class _ShimmerFeedState extends State<_ShimmerFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlight = scheme.surfaceContainerLowest.withValues(alpha: 0.9);

    Widget box(double w, double h, {double radius = 14}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    Widget card(Widget child) => Padding(
          padding: const EdgeInsets.fromLTRB(pageMargin, 0, pageMargin, 16),
          child: child,
        );

    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // The gradient offset runs 0..3 so the highlight band sweeps
          // across, then wraps around.
          final t = _c.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-1 - 2 + 2 * t, 0),
              end: Alignment(-2 + 2 + 2 * t, 0),
              colors: [base, highlight, base],
            ).createShader(bounds),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                card(
                  Container(
                    height: 210,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(pageMargin, 4, pageMargin, 12),
                  child: box(90, 18, radius: 6),
                ),
                for (var i = 0; i < 5; i++)
                  card(
                    Row(
                      children: [
                        box(84, 84, radius: 16),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              box(double.infinity, 14, radius: 6),
                              const SizedBox(height: 8),
                              FractionallySizedBox(
                                widthFactor: 0.7,
                                child: box(double.infinity, 14, radius: 6),
                              ),
                              const SizedBox(height: 10),
                              box(110, 10, radius: 5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown when a filter/search combination matches nothing.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_motion_outlined, size: 44, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'No articles match',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search or filter.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
