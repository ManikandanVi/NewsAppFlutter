import 'package:flutter/material.dart';

import '../data/bookmark_store.dart';

/// Puts the [BookmarkStore] above the widget tree and rebuilds every
/// descendant that depends on it whenever a bookmark changes.
///
/// This is the same idea as an `InheritedWidget`, but listening: each
/// bookmark icon calls `BookmarkScope.of(context)` and is automatically
/// subscribed, so toggling a bookmark in one place updates the icon
/// everywhere (list card, featured card, detail screen) with no manual
/// callback plumbing between screens.
class BookmarkScope extends InheritedNotifier<BookmarkStore> {
  const BookmarkScope({
    super.key,
    required BookmarkStore store,
    required super.child,
  }) : super(notifier: store);

  /// Marks the calling widget as dependent on the store. A `null` return
  /// is legal (used by tests that build without the scope), so callers
  /// handle that instead of asserting.
  static BookmarkStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BookmarkScope>()?.notifier;

  @override
  bool updateShouldNotify(InheritedNotifier<BookmarkStore> oldWidget) =>
      oldWidget.notifier != notifier;
}