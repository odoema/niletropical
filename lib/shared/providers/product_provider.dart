/// Nile Tropical - Product Providers
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/env.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

/// Featured products for Home screen
final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  try {
    final data = await SupabaseService.fetchFeaturedProducts();
    return data.map((json) => Product.fromJson(json)).toList();
  } catch (e) {
    // Mock fallback is intentionally restricted to development. A
    // staging/production build must surface the real error rather than
    // silently showing fake products (see AUDIT.md §64 "no fake success").
    if (Env.isDevelopment) {
      return _mockProducts.where((p) => p.isFeatured).toList();
    }
    rethrow;
  }
});

/// All products (with optional search)
final productsProvider =
    FutureProvider.family<List<Product>, String?>((ref, search) async {
  try {
    final data = await SupabaseService.fetchProducts(search: search);
    return data.map((json) => Product.fromJson(json)).toList();
  } catch (e) {
    if (!Env.isDevelopment) rethrow;
    if (search == null || search.isEmpty) return _mockProducts;
    final q = search.toLowerCase();
    return _mockProducts
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.shortDescription?.toLowerCase().contains(q) ?? false))
        .toList();
  }
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!Env.isConfigured) return const [];
  return SupabaseService.fetchCategories();
});

final bannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!Env.isConfigured) return const [];
  return SupabaseService.fetchBanners();
});

final testimonialsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!Env.isConfigured) return const [];
  return SupabaseService.fetchTestimonials();
});

final videosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!Env.isConfigured) return const [];
  return SupabaseService.fetchPublishedVideos();
});

final promotionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!Env.isConfigured) return const [];
  return SupabaseService.fetchActivePromotions();
});

final flaggedProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, flag) async {
  try {
    final data = await SupabaseService.fetchFlaggedProducts(flag);
    return data.map(Product.fromJson).toList();
  } catch (e) {
    if (!Env.isDevelopment) rethrow;
    return _mockProducts.where((p) {
      switch (flag) {
        case 'is_bestseller':
          return p.isBestseller;
        case 'is_new':
          return p.isNew;
        case 'is_promotional':
          return p.isPromotional;
        default:
          return p.isFeatured;
      }
    }).toList();
  }
});

/// Single product by slug
final productBySlugProvider =
    FutureProvider.family<Product?, String>((ref, slug) async {
  try {
    final data = await SupabaseService.fetchProductBySlug(slug);
    if (data == null) return null;
    return Product.fromJson(data);
  } catch (e) {
    if (!Env.isDevelopment) rethrow;
    try {
      return _mockProducts.firstWhere((p) => p.slug == slug);
    } catch (_) {
      return _mockProducts.first;
    }
  }
});

/// DEVELOPMENT-ONLY fallback catalogue, gated by Env.isDevelopment above.
/// The authoritative version of this same data now lives in
/// supabase/seed/dev_seed.sql for local database seeding — this Dart copy
/// exists only so the UI has something to render before a local Supabase
/// project is set up. Do not add new products here; add them to the seed.
final List<Product> _mockProducts = [
  Product(
    id: '1',
    name: 'E.C.O Shea Butter',
    slug: 'eco-shea-butter',
    shortDescription:
        '100% pure natural shea butter. Rich in vitamins A, E & F.',
    fullDescription:
        'Carefully sourced and processed to retain natural goodness. Ideal for deep moisturising of skin and hair.',
    benefits:
        '• Deeply moisturises\n• Rich in vitamins A, E & F\n• Improves skin elasticity\n• Natural & eco-friendly',
    howToUse:
        'Apply a small amount to clean skin and massage gently. Suitable for face, body and hair.',
    brand: 'Nile Tropical',
    isFeatured: true,
    isBestseller: true,
    variants: const [
      ProductVariant(
        id: 'v1',
        productId: '1',
        sku: 'ECO-SB-250',
        name: '250g',
        price: 10000,
        compareAtPrice: 16000,
        stockQuantity: 45,
      ),
      ProductVariant(
        id: 'v2',
        productId: '1',
        sku: 'ECO-SB-500',
        name: '500g',
        price: 18000,
        compareAtPrice: 25000,
        stockQuantity: 28,
      ),
    ],
    createdAt: DateTime.now(),
  ),
  Product(
    id: '2',
    name: 'White Nile Shea Butter',
    slug: 'white-nile-shea-butter',
    shortDescription: 'Gentle shea butter lotion, perfect for baby care.',
    fullDescription:
        'Soft, nourishing formula specially crafted for sensitive skin.',
    brand: 'Nile Tropical',
    isFeatured: true,
    isNew: true,
    variants: const [
      ProductVariant(
        id: 'v3',
        productId: '2',
        sku: 'WN-SB-250',
        name: '250ml',
        price: 10000,
        stockQuantity: 60,
      ),
    ],
    createdAt: DateTime.now(),
  ),
  Product(
    id: '3',
    name: 'Nile Liquid Hand Sanitizer',
    slug: 'nile-hand-sanitizer',
    shortDescription: 'Effective hand sanitizer available in multiple sizes.',
    brand: 'Nile Tropical',
    isFeatured: true,
    variants: const [
      ProductVariant(
        id: 'v4',
        productId: '3',
        sku: 'NHS-500',
        name: '500ml',
        price: 5000,
        stockQuantity: 120,
      ),
      ProductVariant(
        id: 'v5',
        productId: '3',
        sku: 'NHS-1000',
        name: '1 Litre',
        price: 8000,
        stockQuantity: 80,
      ),
      ProductVariant(
        id: 'v6',
        productId: '3',
        sku: 'NHS-5000',
        name: '5 Litres',
        price: 10000,
        stockQuantity: 25,
      ),
    ],
    createdAt: DateTime.now(),
  ),
  Product(
    id: '4',
    name: 'Hibiscus Tea',
    slug: 'hibiscus-tea',
    shortDescription: 'Natural hibiscus tea – 150g.',
    brand: 'Nile Tropical',
    isFeatured: true,
    isPromotional: true,
    variants: const [
      ProductVariant(
        id: 'v7',
        productId: '4',
        sku: 'HT-150',
        name: '150g',
        price: 10000,
        stockQuantity: 40,
      ),
    ],
    createdAt: DateTime.now(),
  ),
  Product(
    id: '5',
    name: 'Hand Sanitizer Gel',
    slug: 'hand-sanitizer-gel',
    shortDescription: 'Convenient 50ml gel sanitizer.',
    brand: 'Nile Tropical',
    variants: const [
      ProductVariant(
        id: 'v8',
        productId: '5',
        sku: 'HSG-50',
        name: '50ml',
        price: 5000,
        stockQuantity: 200,
      ),
    ],
    createdAt: DateTime.now(),
  ),
];
