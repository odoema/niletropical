/// Nile Tropical - Product Detail (fixes BUG-001: real slug fetch)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/models/product.dart';
import '../../shared/providers/cart_provider.dart';
import '../../shared/providers/product_provider.dart';
import '../../shared/services/supabase_service.dart';
import '../../core/config/env.dart';
import '../../shared/services/storage_service.dart';

final productBySlugProvider =
    FutureProvider.family<Product?, String>((ref, slug) async {
  try {
    final data = await SupabaseService.fetchProductBySlug(slug);
    if (data != null) return Product.fromJson(data);
  } catch (_) {
    if (!Env.isDevelopment) rethrow;
  }
  // Dev fallback from mock list
  final all = await ref.watch(productsProvider(null).future);
  try {
    return all.firstWhere((p) => p.slug == slug);
  } catch (_) {
    return all.isNotEmpty ? all.first : null;
  }
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductVariant? _selected;
  int _qty = 1;

  @override
  void dispose() {
    // A product may have had its images changed while this detail view was open.
    // Invalidate catalogue caches when leaving so the next catalogue view reads
    // the current authoritative product_images rows from Supabase.
    ref.invalidate(featuredProductsProvider);
    ref.invalidate(productsProvider(null));
    ref.invalidate(flaggedProductsProvider('is_bestseller'));
    ref.invalidate(flaggedProductsProvider('is_new'));
    ref.invalidate(flaggedProductsProvider('is_promotional'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productBySlugProvider(widget.slug));

    return async.when(
      loading: () => const Scaffold(body: NileLoadingState()),
      error: (e, _) => Scaffold(
        appBar: const NileAppBar(title: 'Product'),
        body: NileErrorState(message: e.toString(), onRetry: () => ref.invalidate(productBySlugProvider(widget.slug))),
      ),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: const NileAppBar(title: 'Product'),
            body: const NileEmptyState(title: 'Product not found', icon: Icons.search_off),
          );
        }
        _selected ??= product.defaultVariant;
        final variant = _selected ?? product.defaultVariant;
        if (variant == null) {
          return Scaffold(
            appBar: NileAppBar(title: product.name),
            body: const NileEmptyState(title: 'No variants available'),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: NileColors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: _Gallery(product: product),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(NileSpacing.md, NileSpacing.lg, NileSpacing.md, NileSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.brand.toUpperCase(),
                        style: NileTypography.labelSmall.copyWith(
                          color: NileColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        style: NileTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                      if (product.shortDescription != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          product.shortDescription!,
                          style: NileTypography.bodyLarge.copyWith(
                            color: NileColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          NilePrice(
                            amount: variant.price,
                            style: NileTypography.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (variant.hasDiscount) ...[
                            const SizedBox(width: 10),
                            NilePrice(amount: variant.compareAtPrice!, strikeThrough: true),
                            const SizedBox(width: 8),
                            NileBadge(
                              label: '-${variant.discountPercentage.round()}%',
                              variant: NileBadgeVariant.error,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (variant.inStock)
                        NileBadge(label: 'In stock', variant: NileBadgeVariant.success)
                      else
                        const NileBadge(label: 'Out of stock', variant: NileBadgeVariant.error),

                      if (product.variants.length > 1) ...[
                        const SizedBox(height: NileSpacing.lg),
                        Text('Choose size', style: NileTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: product.variants.map((v) {
                            final selected = v.id == variant.id;
                            return ChoiceChip(
                              label: Text(v.name),
                              selected: selected,
                              onSelected: (_) => setState(() {
                                _selected = v;
                                _qty = 1;
                              }),
                              selectedColor: NileColors.primaryContainer,
                              labelStyle: NileTypography.labelMedium.copyWith(
                                color: selected ? NileColors.primary : NileColors.textPrimary,
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: NileSpacing.lg),
                      Text('Quantity', style: NileTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('$_qty', style: NileTypography.titleLarge),
                          ),
                          IconButton.filledTonal(
                            onPressed: variant.inStock ? () => setState(() => _qty++) : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),

                      if (product.fullDescription != null) ...[
                        const SizedBox(height: NileSpacing.xl),
                        Text('About this product', style: NileTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(product.fullDescription!, style: NileTypography.bodyLarge.copyWith(height: 1.6, color: NileColors.textSecondary)),
                      ],
                      if (product.howToUse != null) ...[
                        const SizedBox(height: NileSpacing.lg),
                        Text('How to use', style: NileTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(product.howToUse!, style: NileTypography.bodyLarge.copyWith(height: 1.6, color: NileColors.textSecondary)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(NileSpacing.md),
              child: NileButton(
                label: variant.inStock ? 'Add to cart' : 'Out of stock',
                icon: Icons.shopping_bag_outlined,
                onPressed: variant.inStock
                    ? () {
                        ref.read(cartProvider.notifier).addItem(product, variant, quantity: _qty);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Added to cart'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            margin: const EdgeInsets.only(
                              left: NileSpacing.md,
                              right: NileSpacing.md,
                              bottom: 96,
                            ),
                            action: SnackBarAction(
                              label: 'View cart',
                              onPressed: () => context.push('/cart'),
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product});
  final Product product;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the gallery's first frame identical to Product.mainImageUrl.
    // Do not depend on the database's nested-row order.
    final orderedImages = [...widget.product.images]
      ..sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aCreated.compareTo(bCreated);
      });
    final urls = orderedImages.map((i) => i.url).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty && widget.product.mainImageUrl != null) {
      urls.add(widget.product.mainImageUrl!);
    }
    if (urls.isEmpty) {
      return Container(
        color: NileColors.primaryContainer,
        child: const Center(
          child: Image(
            image: AssetImage('assets/images/logo.png'),
            width: 96,
            height: 96,
          ),
        ),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
        final u = StorageService.resolvePublicUrl(urls[i]);
        if (u.startsWith('http')) {
          return _GalleryImage(url: u);
        }
        return Container(
          color: NileColors.primaryContainer,
          alignment: Alignment.center,
          child: Text(u, style: NileTypography.bodySmall),
        );
          },
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? NileColors.primary : NileColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NileColors.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      child: Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          width: double.infinity,
          height: double.infinity,
          color: NileColors.surfaceVariant,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported_outlined,
                color: NileColors.primary,
                size: 52,
              ),
              const SizedBox(height: 10),
              Text(
                'Product image unavailable',
                style: NileTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
