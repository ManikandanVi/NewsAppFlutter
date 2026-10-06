import 'package:flutter/material.dart';

import '../data/article.dart';
import 'bookmark_scope.dart';
import 'detail_screen.dart';
import 'tokens.dart';
import 'widgets/article_card.dart';

/// The user's saved ("read later") articles. Reads straight from
/// BookmarkScope — no local copy of the list — so un-saving from here
/// (or anywhere) updates the screen instantly, and the list survives
/// app restarts because BookmarkStore persists to disk.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  void _open(BuildContext context, Article article) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // dependOnInheritedWidgetOfExactType inside maybeOf subscribes this
    // build to the store: every toggle rebuilds the list here too.
    final saved = BookmarkScope.maybeOf(context)?.savedArticles ?? const [];

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'Saved (${saved.length})',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: saved.isEmpty
          ? _EmptySaved(onBrowse: () => Navigator.of(context).maybePop())
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  pageMargin, 8, pageMargin, 32),
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final article = saved[index];
                return ArticleCard(
                  article: article,
                  onTap: () => _open(context, article),
                );
              },
            ),
    );
  }
}

/// Shown when nothing has been saved yet, with a nudge back to the feed.
class _EmptySaved extends StatelessWidget {
  const _EmptySaved({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_add_outlined, size: 44, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'No saved articles yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the bookmark on any article\nto read it later — even offline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Browse articles'),
            ),
          ],
        ),
      ),
    );
  }
}