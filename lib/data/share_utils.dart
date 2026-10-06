/// Sharing helpers. One home for the "what gets shared" formatting so
/// every surface (cards, detail screen) shares the exact same text —
/// change it here and all entry points follow.
library;

import 'package:share_plus/share_plus.dart';

import 'article.dart';

/// Shares an article's title + link through the OS share sheet
/// (Android's Sharesheet, iOS's Share Sheet, a web polyfill where
/// available). Fire-and-forget: the sheet is the user's business; we
/// don't track what they picked.
Future<void> shareArticle(Article article) async {
  // Title first so the link never stands alone in a chat bubble.
  await Share.share('${article.title}\n${article.url}');
}