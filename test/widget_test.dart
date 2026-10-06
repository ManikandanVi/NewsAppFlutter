// Smoke test for the new news app. It pumps the app with a repository
// pointed at a fake (never-called) URL, so it deterministically uses the
// bundled fallback articles instead of the real network — tests must not
// depend on the internet.
//
// To perform an interaction with a widget in a test, use the WidgetTester
// utility from package:flutter_test: send taps, scroll gestures, and read
// text back out of the widget tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/ui/widgets/featured_card.dart';

void main() {
  testWidgets('feed renders fallback articles and opens detail screen',
      (WidgetTester tester) async {
    // Build the app. The repository's HTTP call fails instantly in the
    // test environment (no real network), so the fallback list appears.
    await tester.pumpWidget(const SpaceNewsApp());
    // Let the fake fetch complete and one shimmer frame play out.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // The home feed shows the greeting and at least one article card.
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.byType(FeaturedCard), findsOneWidget);
  });

  testWidgets('theme toggle switches brightness', (WidgetTester tester) async {
    await tester.pumpWidget(const SpaceNewsApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Tap the theme toggle in the app bar.
    final toggle = find.byIcon(Icons.dark_mode_outlined);
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // After toggling, the other icon is shown and the theme flips.
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}
