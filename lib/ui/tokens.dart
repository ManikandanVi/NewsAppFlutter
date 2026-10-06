/// Design tokens: the small set of shared values every screen uses so the
/// layout stays consistent. If a padding/margin ever needs to change,
/// change it here — every widget that imports this file follows.
library;

/// Horizontal page margin used by every section of the home feed
/// (header, search, chips, banner, featured card, article cards, list
/// titles, shimmer). Cards' left/right edges and all text baselines line
/// up because they all derive from this one number.
const double pageMargin = 20;

/// Standard gap between cards in the feed.
const double cardGap = 14;
