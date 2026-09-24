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
                expandedHeight: 300,
                pinned: true,
                backgroundColor: NileColors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: _Gallery(product: product),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(NileSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: NileTypography.headlineMedium),
                      if (product.shortDescription != null) ...[
                        const SizedBox(height: 8),
                        Text(product.shortDescription!, style: NileTypography.bodyMedium),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          NilePrice(amount: variant.price, style: NileTypography.headlineSmall),
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
                        Text('Size', style: NileTypography.titleSmall),
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
                      Text('Quantity', style: NileTypography.titleSmall),
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
                        Text('Description', style: NileTypography.titleMedium),
                        const SizedBox(height: 8),
                        Text(product.fullDescription!, style: NileTypography.bodyLarge),
                      ],
                      if (product.howToUse != null) ...[
                        const SizedBox(height: NileSpacing.lg),
                        Text('How to use', style: NileTypography.titleMedium),
                        const SizedBox(height: 8),
                        Text(product.howToUse!, style: NileTypography.bodyLarge),
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

class _Gallery extends StatelessWidget {
  const _Gallery({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    // Always put the catalogue's main image first. The database may contain
    // older gallery images, but opening a product should show the same image
    // the shop card marks as the main image.
    final orderedImages = [...product.images]
      ..sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final createdCompare = bCreated.compareTo(aCreated);
        if (createdCompare != 0) return createdCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    final urls = orderedImages.map((i) => i.url).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty && product.mainImageUrl != null) {
      urls.add(product.mainImageUrl!);
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
    return PageView.builder(
      itemCount: urls.length,
      itemBuilder: (_, i) {
        final u = StorageService.resolvePublicUrl(urls[i]);
        if (u.startsWith('http')) {
          return Image.network(u, fit: BoxFit.cover);
        }
        return Container(
          color: NileColors.primaryContainer,
          alignment: Alignment.center,
          child: Text(u, style: NileTypography.bodySmall),
        );
      },
    );
  }
}
