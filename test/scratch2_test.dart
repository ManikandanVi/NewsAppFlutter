import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/article.dart';
import 'package:flutter_application_1/data/news_repository.dart';
import 'package:flutter_application_1/ui/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      'next': hasMore ? 'https://x/?offset=999' : null,
      'previous': null,
      'results': results.map((a) => a.toJson()).toList(),
    });

void main() {
  testWidgets('DEBUG2: 8-card page scroll behavior',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var calls = 0;
    List<Article> page(int n) => [
          for (var i = 0; i < 8; i++) article('p${n}_$i'),
        ];
    final repo = NewsRepository(client: MockClient((_) async {
      calls++;
      final n = calls;
      // ignore: avoid_print
      print('DBG2 call n=$n');
      return http.Response(envelope(results: page(n), hasMore: n < 3), 200);
    }));

    await tester.pumpWidget(MaterialApp(
      home: NewsHome(
        isDark: false,
        onToggleTheme: () {},
        repository: repo,
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('DBG2 after settle, calls=$calls');

    final rendered = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('Article p') ?? false));
    // ignore: avoid_print
    print(
        'DBG2 rendered: ${tester.widgetList(rendered).map((w) => (w as Text).data).toList()}');

    await tester.fling(
        find.byType(CustomScrollView), const Offset(0, -1500), 1200);
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('DBG2 after fling, calls=$calls');
    final rendered2 = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('Article p') ?? false));
    // ignore: avoid_print
    print(
        'DBG2 rendered2: ${tester.widgetList(rendered2).map((w) => (w as Text).data).toList()}');
  });
}
