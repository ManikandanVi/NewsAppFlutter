// Tests for infinite scroll / pagination.
//
// Two layers are covered:
//
//  1. Repository: FeedPage parsing against scripted MockClient bodies —
//     hasMore from `next`, end-of-feed on `next: null`, error propagation
//     (fetchPage must throw so the UI can offer Retry instead of silently
//     splicing fallback articles into the live feed).
//
//  2. Screen: the full loop with a fake repository — short first page
//     auto-fills, scrolling near the bottom fetches the next page,
//     duplicate ids are dropped, a failed page shows Retry, and Retry
//     recovers. The fake counts calls and replays scripted pages, which
//     keeps every test deterministic (no real network, ever).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/article.dart';
import 'package:flutter_application_1/data/news_repository.dart';
import 'package:flutter_application_1/ui/home_screen.dart';
import 'package:http/http.dart' as http;
// MockClient lives in the testing library, not the main one.
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Article article(String id) => Article(
      id: id,
      title: 'Article $id',
      imageUrl: '',
      summary: 'Summary $id',
      newsSite: 'TestSource',
      publishedAt: DateTime(2026, 1, 1),
      url: 'https://example.com/$id',
    );

String envelope({required List<Article> results, bool hasMore = true}) =>
    jsonEncode({
      'count': 100,
      'next': hasMore
          ? 'https://api.example.test/v4/articles/?limit=5&offset=999'
          : null,
      'previous': null,
      'results': results.map((a) => a.toJson()).toList(),
    });

/// A fake in-memory SharedPreferences-backed store, loaded synchronously —
/// same trick widget_test.dart uses, so no test touches real storage.
Future<void> seedPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

/// Builds NewsHome against [repo] without the full SpaceNewsApp wrapper
/// (bookmarks aren't under test here; a plain MaterialApp keeps the tree
/// small and the failure output readable).
Future<void> pumpFeed(WidgetTester tester, NewsRepository repo) async {
  await tester.pumpWidget(MaterialApp(
    home: NewsHome(
      isDark: false,
      onToggleTheme: () {},
      repository: repo,
    ),
  ));
  await tester.pump(); // kick off the initial load
  await tester.pumpAndSettle(); // let it finish
}

// ---------------------------------------------------------------------------
// Repository tests
// ---------------------------------------------------------------------------

void main() {
  group('NewsRepository.fetchPage', () {
    test('parses a page and reports hasMore from the next field', () async {
      final repo = NewsRepository(
        client: MockClient((_) async =>
            http.Response(envelope(results: [article('1'), article('2')]), 200)),
      );
      final page = await repo.fetchPage(limit: 5);
      expect(page.articles.map((a) => a.id).toList(), ['1', '2']);
      expect(page.hasMore, isTrue);
    });

    test('next: null means the end of the feed', () async {
      final repo = NewsRepository(
        client: MockClient((_) async =>
            http.Response(envelope(results: [article('9')], hasMore: false), 200)),
      );
      final page = await repo.fetchPage(limit: 5);
      expect(page.hasMore, isFalse);
    });

    test('empty results is a valid final page, not an error', () async {
      final repo = NewsRepository(
        client: MockClient((_) async =>
            http.Response(envelope(results: [], hasMore: false), 200)),
      );
      final page = await repo.fetchPage(limit: 5);
      expect(page.articles, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('propagates HTTP errors (no silent fallback splice)', () async {
      final repo = NewsRepository(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      await expectLater(repo.fetchPage(), throwsA(isA<http.ClientException>()));
    });

    test('fetchArticles still falls back on failure', () async {
      final repo = NewsRepository(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      // The initial-load contract is unchanged: always show something.
      final articles = await repo.fetchArticles();
      expect(articles, isNotEmpty);
      expect(repo.lastLoadUsedFallback, isTrue);
    });

    test('requests limit and offset in the query string', () async {
      Uri? captured;
      final repo = NewsRepository(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(envelope(results: [article('1')]), 200);
        }),
      );
      await repo.fetchPage(limit: 7, offset: 14);
      expect(captured!.queryParameters['limit'], '7');
      expect(captured!.queryParameters['offset'], '14');
    });
  });

  // -------------------------------------------------------------------------
  // Screen tests
  // -------------------------------------------------------------------------

  testWidgets('short first page auto-fills until the viewport is scrollable',
      (WidgetTester tester) async {
    await seedPrefs();
    // Pages of 2 articles each, 4 pages scripted. In the 600px test
    // viewport, ~3 cards fit on screen, so the post-frame auto-fill
    // keeps pulling until the list becomes scrollable — with NO user
    // gesture. It stops there (further pages load on scroll).
    var calls = 0;
    final repo = NewsRepository(client: MockClient((_) async {
      calls++;
      final n = calls;
      return http.Response(
          envelope(
              results: [article('a$n'), article('b$n')], hasMore: n < 4),
          200);
    }));

    await pumpFeed(tester, repo);

    // Auto-fill happened without any scroll gesture: page 1 landed and
    // further pages were pulled until the list became scrollable — the
    // scripted end (page 4, hasMore: false) is reached with calls == 4.
    expect(calls, 4);
    // The caught-up footer is rendered below the fold here, so assert
    // it by scrolling to the very bottom of the now-scrollable list.
    await tester.scrollUntilVisible(
      find.text("You're all caught up"),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('scrolling near the bottom fetches the next page',
      (WidgetTester tester) async {
    await seedPrefs();
    // 3 pages of 8 articles: 8 cards make the list scrollable after the
    // first page, so auto-fill stops immediately and the 2nd page must
    // arrive through an actual scroll gesture.
    var calls = 0;
    List<Article> page(int n) => [
          for (var i = 0; i < 8; i++) article('p${n}_$i'),
        ];
    final repo = NewsRepository(client: MockClient((_) async {
      calls++;
      final n = calls;
      return http.Response(
          envelope(results: page(n), hasMore: n < 3), 200);
    }));

    await pumpFeed(tester, repo);

    // Only page 1 so far — the viewport is full and no gesture happened.
    expect(calls, 1);
    expect(find.textContaining('Article p1_'), findsWidgets);
    expect(find.textContaining('Article p2_'), findsNothing);

    // Fling towards the bottom: distance under the threshold fires
    // _loadMore → page 2. (One fling of -1500 lands mid-list on tall
    // 8-card pages, so only page 2's threshold is crossed.)
    await tester.fling(
        find.byType(CustomScrollView), const Offset(0, -1500), 1200);
    await tester.pumpAndSettle();

    expect(calls, greaterThanOrEqualTo(2));
    expect(find.textContaining('Article p2_'), findsWidgets);

    // Second fling reaches the (now further-down) bottom → page 3.
    await tester.fling(
        find.byType(CustomScrollView), const Offset(0, -2500), 1200);
    await tester.pumpAndSettle();

    expect(calls, 3);
    expect(find.textContaining('Article p3_'), findsWidgets);
  });

  testWidgets('duplicate ids from overlapping pages are dropped',
      (WidgetTester tester) async {
    await seedPrefs();
    // Every page returns the SAME two ids (as if the feed shifted under
    // us after a refresh). Dedupe must keep the list at 2, and the
    // "nothing fresh" outcome must end the feed (no infinite refetching).
    var calls = 0;
    final repo = NewsRepository(client: MockClient((_) async {
      calls++;
      return http.Response(
          envelope(results: [article('dup1'), article('dup2')],
              hasMore: calls < 10),
          200);
    }));

    await pumpFeed(tester, repo);
    await tester.pumpAndSettle(); // give any would-be loop time to fire

    // Page 1 loaded; page 2 arrived with nothing new → feed ended, no
    // further calls were made despite hasMore being advertised.
    expect(calls, 2);
    expect(find.text('Article dup1'), findsOneWidget);
    expect(find.text('Article dup2'), findsOneWidget);
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('a failed page keeps the feed and offers Retry that recovers',
      (WidgetTester tester) async {
    await seedPrefs();
    var calls = 0;
    final repo = NewsRepository(client: MockClient((_) async {
      calls++;
      if (calls == 1) {
        // Initial load: one page, more advertised.
        return http.Response(envelope(results: [article('p1a')]), 200);
      }
      if (calls == 2) {
        // The "load more" request fails.
        return http.Response('server exploded', 500);
      }
      // The Retry request succeeds with a full page.
      return http.Response(
          envelope(results: [article('p2a'), article('p2b')],
              hasMore: false),
          200);
    }));

    await pumpFeed(tester, repo);
    // The single article leaves the viewport unfilled, so the post-frame
    // auto-fill ran, its fetch failed, and the error footer rendered —
    // all settled inside pumpFeed.
    await tester.pumpAndSettle();

    // Feed content survived the failure, error footer is showing.
    expect(find.text('Article p1a'), findsOneWidget);
    expect(find.text("Couldn't load more articles"), findsOneWidget);
    final beforeRetry = calls;

    // Retry recovers: error disappears, new articles appear, and the
    // caught-up footer takes over (page said hasMore: false).
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(calls, greaterThan(beforeRetry));
    expect(find.text("Couldn't load more articles"), findsNothing);
    expect(find.text('Article p2a'), findsOneWidget);
    expect(find.text('Article p2b'), findsOneWidget);
    // The Retry-filled page made the list scrollable (footer may be
    // below the fold), so assert its state via scrolling to the end.
    await tester.fling(
        find.byType(CustomScrollView), const Offset(0, -2000), 1200);
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('end of feed shows the caught-up footer',
      (WidgetTester tester) async {
    await seedPrefs();
    final repo = NewsRepository(client: MockClient((_) async {
      return http.Response(
          envelope(results: [article('last1')], hasMore: false), 200);
    }));

    await pumpFeed(tester, repo);

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}