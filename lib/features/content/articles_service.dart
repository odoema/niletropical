import '../../shared/services/supabase_service.dart';

class ArticlesService {
  static const _columns =
      'id,title,content_type,slug,body,caption,byline,cover_media_path,tags,published_at,created_at';

  static Future<List<Map<String, dynamic>>> fetchPublishedArticles() async {
    final response = await SupabaseService.client
        .from('published_articles')
        .select(_columns)
        .eq('content_type', 'news_story')
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
        .select(_columns)
        .eq('content_type', 'news_story')
        .eq('slug', slug)
        .maybeSingle();
  }
}
