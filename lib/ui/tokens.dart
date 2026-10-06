/// Design tokens: the small set of shared values every screen uses so the
/// layout stays consistent. If a padding/margin ever needs to change,
/// change it here — every widget that imports this file follows.
library;

import 'package:flutter/material.dart';

/// Horizontal page margin used by every section of the home feed
/// (header, search, chips, banner, featured card, article cards, list
/// titles, shimmer). Cards' left/right edges and all text baselines line
/// up because they all derive from this one number.
const double pageMargin = 20;

/// Standard gap between cards in the feed.
const double cardGap = 14;

/// The app's single seed colour. Both light and dark themes are derived
/// from this in main.dart; the featured card's bookmark also uses it
/// directly (on its white circle the theme's `primary` can shift tone in
/// dark mode, so the literal seed reads consistently in both).
const seedColor = Color(0xFF4F6DF5);
