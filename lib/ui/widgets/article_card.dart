import 'package:flutter/material.dart';

import '../../data/article.dart';
import '../../data/share_utils.dart';
import '../../data/time_utils.dart';
import '../bookmark_scope.dart';
import '../tokens.dart';

/// A compact horizontal card: thumbnail on the left, text on the right.
/// Used for every article after the first one in the feed, and for the
/// saved list on SavedScreen.
class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, required this.onTap});

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: pageMargin),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SizedBox forces a fixed square for the photo no matter
                // what the network image's intrinsic size is.
                SizedBox(
                  width: 88,
                  height: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      article.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: scheme.outline, size: 26),
                      ),
                      loadingBuilder: (context, child, progress) {
                        // The contract: progress == null means the download
                        // FINISHED (show the image); non-null means we're
                        // still loading (show the spinner).
                        if (progress == null) return child;
                        return Container(
                          color: scheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.outline,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Source + time as a compact overline.
                      Text(
                        '${article.newsSite}  ·  ${timeAgo(article.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        article.shortSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing actions: share (stateless, just opens the
                // OS sheet) and the bookmark toggle, which reads through
                // BookmarkScope so this card rebuilds on any toggle.
                IconButton(
                  tooltip: 'Share article',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: scheme.onSurfaceVariant,
                  onPressed: () => shareArticle(article),
                ),
                _BookmarkButton(article: article, dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bookmark icon shared by every card and the detail screen. Outlined
/// when unsaved, filled when saved; tapping toggles in BookmarkStore.
class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.article, this.dense = false});

  final Article article;

  /// Dense mode for the small list-card row; larger tap target on detail.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = BookmarkScope.maybeOf(context);
    final saved = store?.isSaved(article.id) ?? false;
    return IconButton(
      tooltip: saved ? 'Remove bookmark' : 'Save for later',
      // Keeping the same minimum tap target but a smaller visual icon
      // stops the compact card row from ballooning in height.
      visualDensity: dense ? VisualDensity.compact : null,
      icon: Icon(
        saved ? Icons.bookmark : Icons.bookmark_border,
        size: dense ? 20 : 24,
        color: saved ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onPressed: () => store?.toggle(article),
    );
  }
}
