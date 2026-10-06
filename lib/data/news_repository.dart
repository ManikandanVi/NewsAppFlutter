import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'article.dart';

/// One page of the feed, freshly fetched. `hasMore` mirrors the API's
/// `next` field: non-null means another offset exists to fetch.
class FeedPage {
  const FeedPage({required this.articles, required this.hasMore});

  final List<Article> articles;

  /// Whether fetching a further offset makes sense. A final page may be
  /// short or even empty — an empty `results` with `next: null` is the
  /// API's way of saying "you're past the end", not an error.
  final bool hasMore;
}

/// Knows how to load articles: live from the API, or from the bundled
/// fallback list when the network fails. The UI never talks to HTTP
/// directly — it only asks this class, which keeps the widgets simple and
/// makes the data source swappable (useful for tests, too).
class NewsRepository {
  NewsRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            'https://api.spaceflightnewsapi.net/v4/articles';

  // Dependency injection in miniature: the tests (and we, while building)
  // can hand this a fake client or a local URL instead of the real API.
  final http.Client _client;
  final String _baseUrl;

  bool _lastLoadUsedFallback = false;
  bool get lastLoadUsedFallback => _lastLoadUsedFallback;

  /// Loads one page of articles. The API returns newest first, so no
  /// client-side sorting is needed.
  ///
  /// Any failure — no network, HTTP error, malformed JSON, even an
  /// empty-but-successful response — falls back to the bundled articles
  /// rather than throwing, so the user always sees a feed.
  ///
  /// This is the "first paint" convenience built on top of [fetchPage]:
  /// initial load must always show something, whereas page loads during
  /// scrolling should surface their error to the user (see fetchPage).
  Future<List<Article>> fetchArticles({int limit = 30}) async {
    try {
      final page = await fetchPage(limit: limit);
      if (page.articles.isEmpty) {
        // A well-formed but empty first page would show an empty screen;
        // treat it as a failure so the fallback kicks in instead.
        throw const FormatException('Empty feed');
      }
      return page.articles;
    } catch (e) {
      // One catch-all for anything that can go wrong: timeouts
      // (TimeoutException), no network (SocketException/ClientException),
      // bad JSON (FormatException), ... — all end up on the fallback list.
      _log('load failure', e);
      return _fallback();
    }
  }

  /// Fetches the raw page at [offset]. Unlike [fetchArticles], failures
  /// PROPAGATE to the caller: while scrolling, silently swapping in
  /// fallback articles would splice hand-written stubs into the middle
  /// of the live feed. The UI catches and offers a Retry instead.
  ///
  /// An empty [FeedPage.articles] is a valid result — it means the
  /// offset is past the end of the feed (the API answers 200 with an
  /// empty results array there), so the caller just stops paginating.
  Future<FeedPage> fetchPage({int limit = 30, int offset = 0}) async {
    final uri = Uri.parse('$_baseUrl/?limit=$limit&offset=$offset');
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return parseFeedPage(response.body);
  }

  List<Article> _fallback() {
    _lastLoadUsedFallback = true;
    return getFallbackArticles();
  }

  /// Decodes the API envelope. The v4 API looks like:
  /// `{"count": 36000, "next": "...offset=...", "previous": ..., "results": [...]}`
  /// `next` is null on the last page, which is what [FeedPage.hasMore]
  /// mirrors.
  static FeedPage parseFeedPage(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected JSON shape');
    }
    final results = decoded['results'];
    if (results is! List) {
      throw const FormatException('Missing results array');
    }
    return FeedPage(
      articles: results
          // `whereType` + cast keeps a single malformed entry from crashing
          // the whole load — it just gets skipped.
          .whereType<Map<String, dynamic>>()
          .map(Article.fromJson)
          .toList(),
      hasMore: decoded['next'] != null,
    );
  }

  /// Legacy single-list parser, kept for compatibility. Equivalent to
  /// [parseFeedPage] but discards pagination info.
  static List<Article> parseArticles(String body) =>
      parseFeedPage(body).articles;

  void _log(String what, Object e) {
    // ignore: avoid_print — print is fine for learning/debug builds.
    print('NewsRepository: $what → using fallback data ($e)');
  }
}
