/// Nile Tropical - Product Models
/// Copyright © Hon. Dr. Betty Udongo Pacutho

class Product {
  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? fullDescription;
  final String? benefits;
  final String? howToUse;
  final String? ingredients;
  final String? warnings;
  final String brand;
  final bool isFeatured;
  final bool isBestseller;
  final bool isNew;
  final bool isPromotional;
  final bool isActive;
  final String? categoryId;
  final List<ProductVariant> variants;
  final List<ProductImage> images;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.slug,
    this.shortDescription,
    this.fullDescription,
    this.benefits,
    this.howToUse,
    this.ingredients,
    this.warnings,
    this.brand = 'Nile Tropical',
    this.isFeatured = false,
    this.isBestseller = false,
    this.isNew = false,
    this.isPromotional = false,
    this.isActive = true,
    this.categoryId,
    this.variants = const [],
    this.images = const [],
    required this.createdAt,
  });

  ProductVariant? get defaultVariant =>
      variants.isNotEmpty ? variants.first : null;

  String? get mainImageUrl {
    if (images.isEmpty) return null;

    // The main-image invariant is: exactly one image is main for a product.
    // Sort order is the canonical catalogue order; creation time is only a
    // deterministic tie-breaker. This makes the shop card and product detail
    // resolve the same image independently of Supabase nested-row ordering.
    final candidates = [...images]
      ..sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aCreated.compareTo(bCreated);
      });
    return candidates.first.url;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      shortDescription: json['short_description'] as String?,
      fullDescription: json['full_description'] as String?,
      benefits: json['benefits'] as String?,
      howToUse: json['how_to_use'] as String?,
      ingredients: json['ingredients'] as String?,
      warnings: json['warnings'] as String?,
      brand: json['brand'] as String? ?? 'Nile Tropical',
      isFeatured: json['is_featured'] as bool? ?? false,
      isBestseller: json['is_bestseller'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? false,
      isPromotional: json['is_promotional'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      categoryId: json['category_id'] as String?,
      variants: (json['product_variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      images: (json['product_images'] as List<dynamic>?)
              ?.map((i) => ProductImage.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProductVariant {
  final String id;
  final String productId;
  final String sku;
  final String name;
  final double price;
  final double? costPrice;
  final double? compareAtPrice;
  final int stockQuantity;
  final int reorderLevel;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    required this.price,
    this.costPrice,
    this.compareAtPrice,
    this.stockQuantity = 0,
    this.reorderLevel = 5,
    this.isActive = true,
  });

  bool get inStock => stockQuantity > 0;
  bool get isLowStock => stockQuantity <= reorderLevel && stockQuantity > 0;
  bool get hasDiscount =>
      compareAtPrice != null && compareAtPrice! > price;

  double get discountPercentage {
    if (!hasDiscount) return 0;
    return ((compareAtPrice! - price) / compareAtPrice!) * 100;
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      compareAtPrice: (json['compare_at_price'] as num?)?.toDouble(),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 5,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class ProductImage {
  final String id;
  final String productId;
  final String? variantId;
  final String url;
  final String? altText;
  final int sortOrder;
  final bool isMain;
  final DateTime? createdAt;

  const ProductImage({
    required this.id,
    required this.productId,
    this.variantId,
    required this.url,
    this.altText,
    this.sortOrder = 0,
    this.isMain = false,
    this.createdAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      // storage_path is the authoritative catalogue image reference.
      // Prefer it even if an older schema/view still exposes a stale url field.
      url: (json['storage_path'] ?? json['url'] ?? '').toString(),
      altText: json['alt_text'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isMain: json['is_main'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
