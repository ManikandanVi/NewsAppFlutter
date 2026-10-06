import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'article.dart';

/// Holds the user's saved articles and keeps them on disk.
///
/// Articles are persisted *whole* (as JSON), not just as ids: the feed
/// reloads from the API on every launch, so an article saved today might
/// not be in tomorrow's feed — by id alone it would become unresolvable.
/// Storing the full object means the Saved screen works offline forever.
///
/// Extends [ChangeNotifier] so the UI can listen once and rebuild
/// everywhere (cards, detail, saved list) on every change — see
/// BookmarkScope, the widget that subscribes for the whole tree.
class BookmarkStore extends ChangeNotifier {
  static const _prefsKey = 'bookmarks_v1';

  /// Insertion-ordered id → article map. A Map (not a List) gives O(1)
  /// `isSaved` checks for the bookmark icons, while preserving the
  /// "newest saved first" order we display in.
  final LinkedHashMap<String, Article> _byId = LinkedHashMap();

  SharedPreferences? _prefs;
  bool _loaded = false;

  /// Whether the initial restore from disk has finished. The UI shows
  /// nothing bookmark-dependent until this is true, so a saved icon
  /// never flashes on/off during startup.
  bool get loaded => _loaded;

  /// Saved articles, newest first (map iteration order = insertion order).
  List<Article> get savedArticles => _byId.values.toList().reversed.toList();

  bool isSaved(String id) => _byId.containsKey(id);

  /// Adds the article if absent, removes it if present. Returns whether
  /// it is saved *after* the call, so a toggle button can update its
  /// icon from the return value alone.
  Future<bool> toggle(Article article) async {
    final nowSaved = _byId.remove(article.id) == null;
    if (nowSaved) _byId[article.id] = article;
    notifyListeners();
    await _persist();
    return nowSaved;
  }

  /// Restores the saved list from disk. Called once, before runApp, so
  /// the first frame already knows every bookmark.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final entry in list) {
            if (entry is Map<String, dynamic>) {
              final article = Article.fromJson(entry);
              _byId[article.id] = article;
            }
          }
        }
      }
    } catch (e) {
      // Corrupt or unreadable data must never block the app from
      // starting — we just begin with an empty bookmark list.
      debugPrint('BookmarkStore: restore failed, starting empty ($e)');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Writes the whole list to disk. One key holding a JSON array keeps
  /// the format trivially versionable (bump the `_prefsKey` suffix to
  /// migrate). Failures are swallowed: saving a bookmark should never
  /// crash the UI — worst case the choice is lost on restart.
  Future<void> _persist() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final json = jsonEncode(_byId.values.map((a) => a.toJson()).toList());
      await prefs.setString(_prefsKey, json);
    } catch (e) {
      debugPrint('BookmarkStore: persist failed ($e)');
    }
  }
}