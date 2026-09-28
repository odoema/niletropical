import 'package:flutter/material.dart';
import '../../core/widgets/nile_widgets.dart';
import 'articles_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.slug});
  final String slug;
  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<Map<String, dynamic>?> _future;
  @override
  void initState() {
    super.initState();
    _future = ArticlesService.fetchPublishedArticle(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const NileLoadingState();
          if (snapshot.hasError) return const NileErrorState(message: 'We could not load this article right now.');
          final article = snapshot.data;
          if (article == null) return const NileEmptyState(title: 'Article not found', message: 'This article is not currently published.');
          final title = article['title']?.toString() ?? 'Untitled';
          final caption = article['caption']?.toString() ?? '';
          final byline = article['byline']?.toString() ?? '';
          final body = article['body']?.toString() ?? '';
          final published = DateTime.tryParse(article['published_at']?.toString() ?? '');
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineMedium),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(caption, style: Theme.of(context).textTheme.titleLarge),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      if (byline.isNotEmpty) Text(byline),
                      if (published != null) ...[
                        if (byline.isNotEmpty) const SizedBox(width: 10),
                        Text('• ${published.toLocal().day}/${published.toLocal().month}/${published.toLocal().year}'),
                      ],
                    ]),
                    const Divider(height: 36),
                    ...body.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).map(
                      (paragraph) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(paragraph.trim(), style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
