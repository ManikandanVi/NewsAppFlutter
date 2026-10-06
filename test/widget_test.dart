// Smoke + bookmark tests for the news app.
//
// Tests must never depend on the internet or real device storage:
//  - The HTTP fetch fails instantly in the test environment, so the feed
//    deterministically shows the bundled fallback articles.
//  - SharedPreferences.setMockInitialValues() replaces the platform
//    plugin with an in-memory map, so bookmark/theme persistence is
//    testable (and a fresh mock per test means no state leaks between
//    tests).
//
// To perform an interaction with a widget in a test, use the WidgetTester
// utility from package:flutter_test: send taps, scroll gestures, and read
// text back out of the widget tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/article.dart';
import 'package:flutter_application_1/data/bookmark_store.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/ui/widgets/featured_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The share sheet is a platform channel; the test binding replaces it
// with a mock that records every call, so tests can assert exactly what
// text the app asked to share.
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart'
    show MethodChannelShare;
import 'package:share_plus_platform_interface/platform_interface/share_plus_platform.dart'
    show SharePlatform;

/// Builds the app exactly as main() would, but with test-friendly
/// storage: an in-memory SharedPreferences and a store already loaded
/// from it. Returns the store so tests can assert on it directly.
Future<BookmarkStore> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = BookmarkStore();
  await store.load();
  await tester.pumpWidget(SpaceNewsApp(bookmarkStore: store));
  // Let the fake fetch complete and one shimmer frame play out.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return store;
}

void main() {
  testWidgets('feed renders fallback articles and opens detail screen',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // The home feed shows the greeting and at least one article card.
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.byType(FeaturedCard), findsOneWidget);
  });

  testWidgets('theme toggle switches brightness and persists the choice',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Tap the theme toggle in the header.
    final toggle = find.byIcon(Icons.dark_mode_outlined);
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // After toggling, the other icon is shown and the theme flips.
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    // The choice was written to (mock) storage and the in-memory
    // app state now matches it.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode_v1'), true);
  });

  testWidgets('tapping a card bookmark saves the article and updates badge',
      (WidgetTester tester) async {
    final store = await pumpApp(tester);

    // Nothing is saved yet: no header badge.
    expect(store.savedArticles, isEmpty);
    expect(find.text('1'), findsNothing);

    // Tap the featured card's bookmark. (The header's "Saved articles"
    // button shares the bookmark_border icon, so target the card's
    // "Save for later" tooltip instead.)
    await tester.tap(find.byTooltip('Save for later').first);
    await tester.pumpAndSettle();

    // The store now holds the featured article (fb-1)...
    expect(store.savedArticles, hasLength(1));
    expect(store.isSaved('fb-1'), isTrue);

    // ...and the header shows a badge with the count.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('saved screen lists saved articles and can un-save them',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Save two articles from the feed: the featured card first, then
    // the top list card (the featured button now reads "Remove
    // bookmark", so the next "Save for later" match is fb-2's card).
    await tester.tap(find.byTooltip('Save for later').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save for later').first);
    await tester.pumpAndSettle();

    // Open the saved screen via the header bookmark button.
    await tester.tap(find.byTooltip('Saved articles'));
    await tester.pumpAndSettle();

    // The screen title shows the count and both saved titles appear.
    expect(find.text('Saved (2)'), findsOneWidget);
    expect(find.textContaining('JWST peers into'), findsOneWidget);
    expect(find.textContaining('Artemis II crew'), findsOneWidget);

    // Un-save the topmost card (fb-2, newest saved first): its button
    // is filled now.
    await tester.tap(find.byIcon(Icons.bookmark).first);
    await tester.pumpAndSettle();

    // List shrank to one; fb-2 is gone, fb-1 remains.
    expect(find.text('Saved (1)'), findsOneWidget);
    expect(find.textContaining('Artemis II crew'), findsNothing);
    expect(find.textContaining('JWST peers into'), findsOneWidget);
  });

  testWidgets('saved screen shows an empty state when nothing is saved',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Saved articles'));
    await tester.pumpAndSettle();

    expect(find.text('No saved articles yet'), findsOneWidget);
    expect(find.text('Browse articles'), findsOneWidget);
  });

  testWidgets('share buttons exist on feed and detail, and share the article',
      (WidgetTester tester) async {
    // Mock the share channel before building: every Share.share() call
    // is recorded instead of trying to open a real OS sheet.
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelShare.channel, (call) async {
      calls.add((call.arguments as Map)['text'] as String? ?? '');
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    // Swap the plugin's platform instance for the mock channel one.
    SharePlatform.instance = MethodChannelShare();

    await pumpApp(tester);

    // Feed: featured card + first list card each carry a share button.
    final feedShareButtons = find.byTooltip('Share article');
    expect(feedShareButtons, findsAtLeastNWidgets(2));

    // Tap the first one (featured card's button) — nothing throws, and
    // the share sheet received the title + url of the featured article.
    await tester.tap(feedShareButtons.first);
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single, contains('https://'));
    expect(calls.single, contains('\n'));

    // Detail screen: open the featured article, tap its Share button.
    await tester.tap(find.textContaining('JWST peers into'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    final before = calls.length;
    // The button row sits below the 600px test viewport's fold — bring
    // it into view before tapping, or the tap silently misses.
    await tester.ensureVisible(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(calls.length, greaterThan(before));
    expect(calls.last, contains('science.nasa.gov'));
  });

  test('bookmark store round-trips articles through storage', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final first = BookmarkStore();
    await first.load();
    await first.toggle(_article('fb-9'));
    await first.toggle(_article('fb-10'));

    // A brand-new store reading the same (mock) storage restores both,
    // newest first — the same thing that happens across an app restart.
    final second = BookmarkStore();
    await second.load();
    expect(second.savedArticles.map((a) => a.id).toList(),
        ['fb-10', 'fb-9']);
    expect(second.savedArticles.first.title, 'Test article fb-10');
  });

  test('toggling twice returns to unsaved', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = BookmarkStore();
    await store.load();

    expect(await store.toggle(_article('fb-1')), isTrue);
    expect(await store.toggle(_article('fb-1')), isFalse);
    expect(store.savedArticles, isEmpty);
  });
}

/// A minimal article for store-level tests (no widget tree involved).
Article _article(String id) => Article(
      id: id,
      title: 'Test article $id',
      imageUrl: '',
      summary: 'Summary for $id',
      newsSite: 'TestSource',
      publishedAt: DateTime(2026, 1, 1),
      url: 'https://example.com/$id',
    );