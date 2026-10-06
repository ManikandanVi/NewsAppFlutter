import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'article.dart';

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
  Future<List<Article>> fetchArticles({int limit = 30}) async {
    final uri = Uri.parse('$_baseUrl/?limit=$limit');
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }
      final articles = parseArticles(response.body);
      if (articles.isEmpty) {
        // A well-formed but empty response would show an empty screen;
        // treat it as a failure so the fallback kicks in instead.
        throw const FormatException('Empty feed');
      }
      _lastLoadUsedFallback = false;
      return articles;
    } catch (e) {
      // One catch-all for anything that can go wrong: timeouts
      // (TimeoutException), no network (SocketException/ClientException),
      // bad JSON (FormatException), ... — all end up on the fallback list.
      _log('load failure', e);
      return _fallback();
    }
  }

  List<Article> _fallback() {
    _lastLoadUsedFallback = true;
    return getFallbackArticles();
  }

  /// Decodes the API envelope. The v4 API looks like:
  /// `{"count": 36000, "results": [ {...article...}, ... ]}`
  static List<Article> parseArticles(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected JSON shape');
    }
    final results = decoded['results'];
    if (results is! List) {
      throw const FormatException('Missing results array');
    }
    return results
        // `whereType` + cast keeps a single malformed entry from crashing
        // the whole load — it just gets skipped.
        .whereType<Map<String, dynamic>>()
        .map(Article.fromJson)
        .toList();
  }

  void _log(String what, Object e) {
    // ignore: avoid_print — print is fine for learning/debug builds.
    print('NewsRepository: $what → using fallback data ($e)');
  }
}
