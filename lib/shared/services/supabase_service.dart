/// Nile Tropical - Supabase Service
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  // Helper for public product queries
  static Future<List<Map<String, dynamic>>> fetchFeaturedProducts() async {
    final response = await client
        .from('products')
        .select('''
          *,
          product_variants (*),
          product_images (*)
        ''')
        .eq('is_active', true)
        .eq('is_featured', true)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> fetchProducts({
    String? categorySlug,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = client
        .from('products')
        .select('''
          *,
          product_variants (*),
          product_images (*)
        ''')
        .eq('is_active', true)
        .isFilter('deleted_at', null);

    if (search != null && search.isNotEmpty) {
      query = query.or(
        'name.ilike.%$search%,short_description.ilike.%$search%',
      );
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Complete catalogue query for the admin Products screen.
  /// Includes inactive products so administrators can search the full catalogue.
  static Future<List<Map<String, dynamic>>> fetchAdminProducts({
    String? search,
    int limit = 50,
  }) async {
    final q = (search ?? '').trim();
    var query = client
        .from('products')
        .select('''
          *,
          product_variants (*),
          product_images (*)
        ''')
        .isFilter('deleted_at', null);

    if (q.isNotEmpty) {
      final escaped = q.replaceAll('%', '\\%').replaceAll('_', '\\_');
      query = query.or(
        'name.ilike.%$escaped%,slug.ilike.%$escaped%,short_description.ilike.%$escaped%,full_description.ilike.%$escaped%',
      );
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> fetchProductBySlug(String slug) async {
    final response = await client
        .from('products')
        .select('''
          *,
          product_variants (*),
          product_images (*),
          product_videos (*)
        ''')
        .eq('slug', slug)
        .eq('is_active', true)
        .isFilter('deleted_at', null)
        .maybeSingle();

    return response;
  }

  static Future<List<Map<String, dynamic>>> fetchTable(
    String table, {
    String? order,
    bool ascending = true,
  }) async {
    var q = client.from(table).select();
    final response = order == null
        ? await q
        : await q.order(order, ascending: ascending);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> fetchBanners() async {
    final response = await client
        .from('banners')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    final now = DateTime.now().toUtc();
    return List<Map<String, dynamic>>.from(response).where((row) {
      final starts = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final ends = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      final afterStart = starts == null || !now.isBefore(starts.toUtc());
      final beforeEnd = ends == null || now.isBefore(ends.toUtc());
      return afterStart && beforeEnd;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchPublishedFaqs() async {
    final response = await client
        .from('faqs')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> fetchPage(String slug) async {
    return client
        .from('pages')
        .select()
        .eq('slug', slug)
        .eq('is_published', true)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> fetchTestimonials() async {
    final response = await client
        .from('testimonials')
        .select()
        .eq('is_published', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> fetchPublishedVideos() async {
    final response = await client
        .from('videos')
        .select()
        .eq('is_published', true)
        .order('sort_order')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> fetchActivePromotions() async {
    final response = await client
        .from('promotions')
        .select()
        .eq('is_active', true)
        .order('starts_at');

    final now = DateTime.now().toUtc();
    return List<Map<String, dynamic>>.from(response).where((row) {
      final starts = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final ends = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      final afterStart = starts == null || !now.isBefore(starts.toUtc());
      final beforeEnd = ends == null || now.isBefore(ends.toUtc());
      return afterStart && beforeEnd;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchFlaggedProducts(String flag) async {
    final response = await client
        .from('products')
        .select('*, product_variants (*), product_images (*)')
        .eq('is_active', true)
        .eq(flag, true)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(8);
    return List<Map<String, dynamic>>.from(response);
  }
}
