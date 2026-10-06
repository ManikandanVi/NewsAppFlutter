import 'package:flutter/material.dart';

import '../data/article.dart';
import '../data/news_repository.dart';
import '../data/time_utils.dart';
import 'bookmark_scope.dart';
import 'saved_screen.dart';
import 'tokens.dart';
import 'detail_screen.dart';
import 'widgets/article_card.dart';
import 'widgets/featured_card.dart';

/// The main feed screen: header, search, filter chips, featured card and
/// the scrolling list of articles. It owns all state: the loaded articles,
/// the search text, the active source filter, the loading flags, and the
/// pagination position (infinite scroll).
class NewsHome extends StatefulWidget {
  const NewsHome({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.repository,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  /// Test seam: inject a repository backed by a MockClient to serve
  /// scripted pages. Defaults to the real API.
  final NewsRepository? repository;

  @override
  State<NewsHome> createState() => _NewsHomeState();
}

class _NewsHomeState extends State<NewsHome> {
  // Horizontal rhythm comes from tokens.dart (pageMargin) — same value
  // the cards use, so every edge lines up.
  late final NewsRepository _repo = widget.repository ?? NewsRepository();
  final TextEditingController _searchController = TextEditingController();

  // How far below the viewport bottom triggers the next page fetch.
  // 600px is roughly half a phone screen: early enough that the new
  // cards are usually there before the user reaches the edge, late
  // enough not to fire on every small fling.
  static const double _loadMoreThreshold = 600;

  // Page size for every fetch, initial included.
  static const int _pageSize = 30;

  // Feed state.
  List<Article> _allArticles = const [];
  bool _loading = true;
  bool _usedFallback = false;

  // Pagination state.
  //
  // _nextOffset counts RAW fetched articles, not filtered ones: the
  // search box and source chips narrow what's displayed but must never
  // move the API position, or pages would be skipped/repeated.
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _loadMoreError; // non-null = last page load failed, offer Retry

  // Guard against stale responses: pull-to-refresh bumps the generation,
  // and any page-2+ response that lands after that belongs to the old
  // feed and is discarded rather than appended to the new list.
  int _loadGeneration = 0;

  late final ScrollController _scrollController = ScrollController()
    ..addListener(_onScroll);

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
    _scrollController.dispose();
    super.dispose();
  }

  /// Whether the infinite-scroll footer should currently be visible.
  /// Paused while a search/filter is active: the user is narrowing the
  /// already-loaded set, not browsing for more — auto-fetching during
  /// typing would waste requests and jumble "Results (n)". Pagination
  /// resumes (footer returns) as soon as the query is cleared.
  bool get _paginatePaused => _query.isNotEmpty || _sourceFilter != null;

  Future<void> _load() async {
    // New epoch: any still-in-flight "load more" response is now stale.
    _loadGeneration++;
    final gen = _loadGeneration;
    setState(() {
      _loading = true;
      _loadMoreError = null;
    });
    final articles = await _repo.fetchArticles();
    // If this screen was removed from the tree while the request was in
    // flight (e.g. user quit the app), calling setState would crash.
    if (!mounted) return;
    setState(() {
      _allArticles = articles;
      _usedFallback = _repo.lastLoadUsedFallback;
      _loading = false;
      // The initial loader hides pagination details, so position resets
      // optimistically; the first short/empty page will correct _hasMore.
      _nextOffset = articles.length;
      _hasMore = !_usedFallback;
      _loadingMore = false;
    });
    // If the whole first page fits on screen, there's no scroll event to
    // trigger the next fetch — check now and auto-fill.
    _maybeLoadMoreAfterFrame(gen);
  }

  /// Fetches the next page and appends only articles not already shown.
  ///
  /// Dedupe matters because offsets shift: the API keeps publishing new
  /// articles, so a pull-to-refresh resets to offset 0 while older
  /// articles slide deeper — the page-2 fetch can then overlap the
  /// refreshed first page. Skipping by id keeps the list honest.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _paginatePaused || _loading) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    final gen = _loadGeneration;
    try {
      final page = await _repo.fetchPage(limit: _pageSize, offset: _nextOffset);
      if (!mounted) return;
      if (gen != _loadGeneration) return; // a refresh happened meanwhile
      setState(() {
        // .toList() materializes the filter ONCE, against the old list.
        // A bare `where` iterable would lazily re-evaluate against the
        // just-updated _allArticles below and always come out empty.
        final fresh = page.articles
            .where((a) => !_allArticles.any((e) => e.id == a.id))
            .toList();
        _allArticles = [..._allArticles, ...fresh];
        // Advance by what the server actually returned, not by what we
        // asked for — a server that caps the page size would otherwise
        // cause offset drift and silently skip articles.
        _nextOffset += page.articles.length;
        // Out of pages, or nothing new arrived: the latter ends the feed
        // too, otherwise every scroll to the bottom would re-fetch the
        // same overlap forever.
        _hasMore = page.hasMore && fresh.isNotEmpty;
        _loadingMore = false;
      });
      // Page may have been short — auto-fill if the list still isn't
      // scrollable.
      _maybeLoadMoreAfterFrame(gen);
    } catch (e) {
      if (!mounted) return;
      if (gen != _loadGeneration) return;
      setState(() {
        // Keep the already-loaded content — never wipe the feed for a
        // failed page. The footer turns into a Retry button instead.
        _loadMoreError = 'Couldn\'t load more articles';
        _loadingMore = false;
      });
    }
  }

  /// Runs a bottom-of-list check after the frame settles: needed when a
  /// loaded page is too short to make the list scrollable, in which case
  /// no scroll event would ever fire.
  void _maybeLoadMoreAfterFrame(int gen) {
    if (gen != _loadGeneration || !_hasMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _loadGeneration) return;
      _onScroll();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Error state deliberately blocks auto-retry: a flaky network would
    // otherwise fire the request on every scroll tick. The Retry button
    // in the footer is the way back.
    if (!_loadingMore && _hasMore && !_paginatePaused && _loadMoreError == null) {
      final distance = pos.maxScrollExtent - pos.pixels;
      if (distance < _loadMoreThreshold) _loadMore();
    }
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
          controller: _scrollController,
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
                    onOpenSaved: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SavedScreen(),
                        ),
                      );
                    },
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
                // Infinite-scroll footer. Hidden while a search/filter is
                // narrowing the loaded set (see _paginatePaused), and
                // absent on the offline fallback (no pages to fetch).
                if (!_usedFallback && !_paginatePaused)
                  SliverToBoxAdapter(child: _FeedFooter(state: this)),
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


/// The greeting + date + theme/bookmark buttons block. One Row keeps
/// everything on the same baseline: greeting/date on the left, the
/// saved-articles icon (with count badge) and theme toggle right-aligned.
class _Header extends StatelessWidget {
  const _Header({
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenSaved,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSaved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // Subscribes this header to the bookmark store: the badge count
    // updates live as articles are saved/un-saved anywhere in the app.
    final savedCount =
        BookmarkScope.maybeOf(context)?.savedArticles.length ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(pageMargin, 8, 12, 8),
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Expanded makes the text column take all width minus the icon,
          // so the icons hug the right edge.
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
          // Saved-articles entry point with a live count badge (hidden
          // when nothing is saved yet).
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Saved articles',
                onPressed: onOpenSaved,
                icon: const Icon(Icons.bookmark_border),
              ),
              if (savedCount > 0)
                Positioned(
                  top: 6,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      savedCount > 99 ? '99+' : '$savedCount',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                    ),
                  ),
                ),
            ],
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

/// The infinite-scroll footer at the bottom of the feed. Reads the
/// pagination state straight off the [_NewsHomeState] (it is rebuilt on
/// every setState of that state class, so it always reflects the latest
/// flags) and renders one of three states:
///
///  - spinner while the next page is in flight,
///  - error message + Retry when a page failed (feed content stays),
///  - "You're all caught up" once the API says there is no next page.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state});

  final _NewsHomeState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Error: needs the user's decision, so it's always shown when set —
    // even mid-search pause, hiding a failure behind a filter change
    // would look like the feed just stopped.
    if (state._loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(pageMargin, 20, pageMargin, 8),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, size: 28, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              state._loadMoreError!,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: state._loadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Loading the next page: a slim spinner with a label.
    if (state._loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    // True end of the live feed.
    if (!state._hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(pageMargin, 20, pageMargin, 8),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 28, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Idle with more pages available: reserve a little space so the
    // "caught up" swap doesn't shift content, but show nothing yet —
    // the spinner appears the moment the scroll threshold fires.
    return const SizedBox(height: 8);
  }
}
