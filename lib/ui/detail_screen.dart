import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/article.dart';
import '../data/share_utils.dart';
import '../data/time_utils.dart';
import 'bookmark_scope.dart';

/// Full-screen article view: hero image, source badge, summary and a
/// button that opens the original article in the browser.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.article});

  final Article article;

  Future<void> _openOriginal(BuildContext context) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null) return;
    // launchUrl is fire-and-forget; modeExternalApplication asks the OS
    // to open it outside our app (browser on Android, new tab on web).
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    article.imageUrl,
                    fit: BoxFit.cover,
                    // progress == null ⇒ download finished → show image.
                    // (frameBuilder would also work, but one builder is
                    // easier to read; errorBuilder covers broken URLs and
                    // hosts that don't allow cross-origin reads on web.)
                    errorBuilder: (_, _, _) => _photoPlaceholder(scheme),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : _photoPlaceholder(scheme),
                  ),
                  const _BottomFade(),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source + date row (bookmark lives here too — DetailScreen is a
                  // StatelessWidget, so the icon reads its saved-state from
                  // BookmarkScope and rebuilds on toggle).
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          article.newsSite,
                          style: text.labelMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeAgo(article.publishedAt),
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      _DetailBookmark(article: article),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    article.title,
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 16),
                  // SelectableText lets the reader copy the summary.
                  SelectableText(
                    article.summary.trim().isEmpty
                        ? 'No summary available — open the full story below.'
                        : article.summary.trim(),
                    style: text.bodyLarge?.copyWith(height: 1.65),
                  ),
                  const SizedBox(height: 28),
                  // The two reading actions side by side: open the
                  // original (primary) and share it (tonal). Expanded
                  // gives each an equal half of the row.
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => _openOriginal(context),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Read full story'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.tonalIcon(
                            onPressed: () => shareArticle(article),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Opens ${Uri.tryParse(article.url)?.host ?? 'the source'} in your browser',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.rocket_launch_outlined,
            size: 48, color: scheme.outline),
      );
}

/// The detail screen's bookmark toggle. Same BookmarkScope dependency as
/// the card icons, so all views of one article stay in sync.
class _DetailBookmark extends StatelessWidget {
  const _DetailBookmark({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = BookmarkScope.maybeOf(context);
    final saved = store?.isSaved(article.id) ?? false;
    return IconButton(
      tooltip: saved ? 'Remove bookmark' : 'Save for later',
      icon: Icon(
        saved ? Icons.bookmark : Icons.bookmark_border,
        color: saved ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onPressed: () => store?.toggle(article),
    );
  }
}

/// A gradient that fades the bottom of the hero image into transparency,
/// so the app bar collapsing over it stays readable.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.45, 1.0],
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
    );
  }
}
