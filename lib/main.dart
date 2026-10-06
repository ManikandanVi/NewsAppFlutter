import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/bookmark_store.dart';
import 'ui/bookmark_scope.dart';
import 'ui/home_screen.dart';
import 'ui/tokens.dart';

/// Key under SharedPreferences where the user's explicit dark-mode choice
/// is stored. null = follow the system.
const _darkModePrefsKey = 'dark_mode_v1';

/// The root of the app. Everything above `runApp` is Flutter bootstrap.
Future<void> main() async {
  // Widgets must be initialized before any plugin call (SharedPreferences
  // touches the platform channel) — required whenever main() is async.
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted state before the first frame: bookmarks and the saved
  // dark-mode choice (null = the user never picked, follow the system).
  // Doing this up front means the UI never shows a wrong state that then
  // "jumps" to the right one.
  final store = BookmarkStore();
  await store.load();
  final prefs = await SharedPreferences.getInstance();
  final savedDarkMode = prefs.getBool(_darkModePrefsKey);

  runApp(SpaceNewsApp(
    bookmarkStore: store,
    initialDarkMode: savedDarkMode,
  ));
}

class SpaceNewsApp extends StatefulWidget {
  const SpaceNewsApp({
    super.key,
    required this.bookmarkStore,
    this.initialDarkMode,
  });

  final BookmarkStore bookmarkStore;

  /// The user's persisted dark-mode choice; null = follow the system.
  final bool? initialDarkMode;

  @override
  State<SpaceNewsApp> createState() => _SpaceNewsAppState();
}

class _SpaceNewsAppState extends State<SpaceNewsApp> {
  // The in-memory choice starts from what was persisted (or null to
  // follow the system). Every change is written back to disk, so the
  // choice survives app restarts.
  bool? _darkMode;

  // The single seed colour both themes are derived from — change the one
  // value in tokens.dart and the whole app re-tints (try Colors.teal).
  static const _seed = seedColor;

  ThemeData _theme(Brightness brightness) {
    // `ColorScheme.fromSeed` builds a full, accessible palette (surfaces,
    // containers, on-colors...) from just one colour, and
    // `ThemeData.from` turns that scheme into a Material 3 theme.
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData.from(colorScheme: scheme, useMaterial3: true);
  }

  Future<void> _toggleTheme() async {
    setState(() => _darkMode = !(_darkMode ?? false));
    // Persisted outside setState — disk writes don't belong in a build
    // callback's synchronous part, and a failed write must not break the
    // UI (the in-memory choice above is already applied).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModePrefsKey, _darkMode!);
    } catch (_) {
      // Ignore: worst case the choice reverts on next launch.
    }
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery.platformBrightnessOf listens to the OS theme, so flipping
    // dark mode in Android/Windows settings updates the app live.
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = _darkMode ?? platformDark;

    return BookmarkScope(
      store: widget.bookmarkStore,
      child: MaterialApp(
        title: 'Space News',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: NewsHome(
          isDark: dark,
          onToggleTheme: _toggleTheme,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
  }
}