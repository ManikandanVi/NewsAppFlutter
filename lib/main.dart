import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

void main() {
  runApp(const SpaceNewsApp());
}

/// The root of the app. Everything above `runApp` is Flutter bootstrap.
class SpaceNewsApp extends StatefulWidget {
  const SpaceNewsApp({super.key});

  @override
  State<SpaceNewsApp> createState() => _SpaceNewsAppState();
}

class _SpaceNewsAppState extends State<SpaceNewsApp> {
  // null = follow the system (the default). true/false = the user's
  // explicit choice from the toggle in the app bar. Storing the *choice*
  // instead of a bool keeps the system-following behaviour available.
  bool? _darkMode;

  // The single seed colour both themes are derived from — change this one
  // value and the whole app re-tints (try Colors.teal to see).
  static const _seed = Color(0xFF4F6DF5);

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

  @override
  Widget build(BuildContext context) {
    // MediaQuery.platformBrightnessOf listens to the OS theme, so flipping
    // dark mode in Android/Windows settings updates the app live.
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = _darkMode ?? platformDark;

    return MaterialApp(
      title: 'Space News',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: NewsHome(
        isDark: dark,
        onToggleTheme: () => setState(() => _darkMode = !dark),
      ),
    );
  }
}
