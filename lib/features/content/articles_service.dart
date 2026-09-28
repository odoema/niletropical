import '../../shared/services/supabase_service.dart';

class ArticlesService {
  static Future<List<Map<String, dynamic>>> fetchPublishedArticles() async {
    final response = await SupabaseService.client
        .from('published_articles')
        .select('id,title,slug,body,caption,byline,cover_media_path,tags,published_at,created_at')
        .order('published_at', ascending: false);
    final articles = List<Map<String, dynamic>>.from(response);
    articles.sort((a, b) {
      final aFlag = (a['tags'] as List?)?.contains('FLAGSHIP') ?? false;
      final bFlag = (b['tags'] as List?)?.contains('FLAGSHIP') ?? false;
      if (aFlag != bFlag) return aFlag ? -1 : 1;
      return 0;
    });
    return articles;
  }

  static Future<Map<String, dynamic>?> fetchPublishedArticle(String slug) async {
    return SupabaseService.client
        .from('published_articles')
        .select('id,title,slug,body,caption,byline,cover_media_path,tags,published_at,created_at')
        .eq('status', 'published')
        .eq('content_type', 'news_story')
        .eq('slug', slug)
        .lte('published_at', DateTime.now().toUtc().toIso8601String())
        .maybeSingle();
  }
}
