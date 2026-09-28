import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/nile_widgets.dart';
import 'articles_service.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});
  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = ArticlesService.fetchPublishedArticles();
  }
  void _reload() => setState(() => _future = ArticlesService.fetchPublishedArticles());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Articles')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const NileLoadingState();
          if (snapshot.hasError) {
            return NileErrorState(message: 'We could not load articles right now.', onRetry: _reload);
          }
          final articles = snapshot.data ?? const [];
          if (articles.isEmpty) {
            return const NileEmptyState(title: 'No articles yet', message: 'Published stories will appear here.');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final article = articles[index];
                final title = article['title']?.toString() ?? 'Untitled';
                final caption = article['caption']?.toString() ?? '';
                final slug = article['slug']?.toString() ?? '';
                final byline = article['byline']?.toString() ?? '';
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: slug.isEmpty ? null : () => context.push('/articles/$slug'),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0) const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text('FEATURED STORY', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                          ),
                          Text(title, style: Theme.of(context).textTheme.headlineSmall),
                          if (caption.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(caption, style: Theme.of(context).textTheme.titleMedium),
                          ],
                          if (byline.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(byline, style: Theme.of(context).textTheme.bodySmall),
                          ],
                          const SizedBox(height: 14),
                          const Row(children: [Text('Read article'), SizedBox(width: 6), Icon(Icons.arrow_forward, size: 18)]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
