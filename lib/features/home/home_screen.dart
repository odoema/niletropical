import 'dart:async';
/// Nile Tropical - Home Screen (Nile design system)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/models/product.dart';
import '../../shared/providers/cart_provider.dart';
import '../../shared/providers/product_provider.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final featured = ref.watch(featuredProductsProvider);
    final allProducts = ref.watch(productsProvider(null));
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: NileColors.surface,
            title: Text(
              AppConstants.appName,
              style: NileTypography.titleLarge.copyWith(color: NileColors.primary),
            ),
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined),
                    onPressed: () => context.push('/cart'),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: NileColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$cartCount',
                          style: NileTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Hero story carousel — four slides introducing Nile Tropical Industries.
          const SliverToBoxAdapter(
            child: _NileTropicalHeroCarousel(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: NileSpacing.md)),

          // CMS-managed promotional banners.
          ref.watch(bannersProvider).when(
            data: (banners) => banners.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: SizedBox(
                      height: 190,
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 0.94),
                        itemCount: banners.length,
                        itemBuilder: (context, index) {
                          final banner = banners[index];
                          final path = banner['image_storage_path']?.toString();
                          final url = StorageService.resolvePublicUrl(
                            path,
                            bucket: StorageService.cms,
                          );
                          final link = banner['link_url']?.toString();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ClipRRect(
                              borderRadius: NileRadius.borderLg,
                              child: Material(
                                color: NileColors.surfaceVariant,
                                child: InkWell(
                                  onTap: link == null || link.isEmpty
                                      ? null
                                      : () async {
                                          final uri = Uri.tryParse(link);
                                          if (uri == null) return;
                                          if (uri.scheme == 'http' || uri.scheme == 'https') {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } else if (link.startsWith('/')) {
                                            context.go(link);
                                          }
                                        },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (url.isNotEmpty)
                                        Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.broken_image_outlined),
                                          ),
                                        ),
                                      if (banner['title']?.toString().isNotEmpty == true)
                                        Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            color: Colors.black.withValues(alpha: 0.55),
                                            child: Text(
                                              banner['title'].toString(),
                                              style: NileTypography.titleMedium.copyWith(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: NileSpacing.md)),

          // CMS-managed active promotions.
          ref.watch(promotionsProvider).when(
            data: (promotions) => promotions.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Offers & promotions', style: NileTypography.titleLarge),
                          const SizedBox(height: 8),
                          ...promotions.take(3).map(
                            (promotion) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: NileColors.primaryContainer,
                                  child: Icon(Icons.local_offer_outlined, color: NileColors.primary),
                                ),
                                title: Text(promotion['name']?.toString() ?? ''),
                                subtitle: Text(
                                  promotion['description']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: NileSpacing.md)),

          // Quick links
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
              child: Row(
                children: [
                  _QuickChip(
                    icon: Icons.local_shipping_outlined,
                    label: 'Track order',
                    onTap: () => context.push('/track'),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    icon: Icons.storefront_outlined,
                    label: 'All products',
                    onTap: () => context.go('/shop'),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    icon: Icons.help_outline,
                    label: 'FAQs',
                    onTap: () => context.push('/faq'),
                  ),
                ],
              ),
            ),
          ),

          ref.watch(categoriesProvider).when(
                data: (cats) {
                  if (cats.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
                        scrollDirection: Axis.horizontal,
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final c = cats[i];
                          return ActionChip(
                            label: Text(c['name']?.toString() ?? ''),
                            onPressed: () => context.push('/category/${c['slug']}'),
                          );
                        },
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

          // Featured
          const SliverToBoxAdapter(child: SizedBox(height: NileSpacing.sm)),
          SliverToBoxAdapter(
            child: NileSectionHeader(
              title: 'Featured',
              actionLabel: 'See all',
              onAction: () => context.go('/shop'),
            ),
          ),
          featured.when(
            data: (products) => products.isNotEmpty
                ? _productGrid(products.take(4).toList())
                : allProducts.when(
                    data: (all) => _productGrid(all.take(4).toList()),
                    loading: () => const SliverToBoxAdapter(
                      child: SizedBox(height: 180, child: NileLoadingState()),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: NileErrorState(message: e.toString()),
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(height: 180, child: NileLoadingState()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: NileErrorState(message: e.toString()),
            ),
          ),

          // Show up to four real products for every production category.
          // This keeps the home page populated even when merchandising flags
          // such as featured/bestseller/new have not yet been configured.
          categories.when(
            data: (cats) => allProducts.when(
              data: (products) {
                final groups = <Widget>[];
                for (final category in cats) {
                  final id = category['id']?.toString();
                  final name = category['name']?.toString() ?? 'Products';
                  final slug = category['slug']?.toString();
                  if (id == null) continue;
                  final items = products.where((p) => p.categoryId == id).take(4).toList();
                  if (items.isEmpty) continue;
                  groups.add(
                    SliverToBoxAdapter(
                      child: NileSectionHeader(
                        title: name,
                        actionLabel: 'Shop',
                        onAction: () => slug == null || slug.isEmpty
                            ? context.go('/shop')
                            : context.push('/category/$slug'),
                      ),
                    ),
                  );
                  groups.add(_productGrid(items));
                }
                return groups.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : SliverMainAxisGroup(slivers: groups);
              },
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(height: 180, child: NileLoadingState()),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          SliverToBoxAdapter(
            child: NileSectionHeader(
              title: 'Bestsellers',
              actionLabel: 'Shop',
              onAction: () => context.go('/shop'),
            ),
          ),
          ref.watch(flaggedProductsProvider('is_bestseller')).when(
                data: (p) => _productGrid(
                  (p.isNotEmpty ? p : (allProducts.valueOrNull ?? const <Product>[]))
                      .take(4)
                      .toList(),
                ),
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
          SliverToBoxAdapter(
            child: NileSectionHeader(
              title: 'New',
              actionLabel: 'Shop',
              onAction: () => context.go('/shop'),
            ),
          ),
          ref.watch(flaggedProductsProvider('is_new')).when(
                data: (p) => _productGrid(
                  (p.isNotEmpty ? p : (allProducts.valueOrNull ?? const <Product>[]))
                      .take(4)
                      .toList(),
                ),
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
          ref.watch(videosProvider).when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: NileSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
                            child: Text('Videos', style: NileTypography.titleLarge),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 190,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
                              scrollDirection: Axis.horizontal,
                              itemCount: rows.take(6).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final video = rows[index];
                                final thumb = StorageService.resolvePublicUrl(
                                  video['thumbnail_path']?.toString(),
                                  bucket: StorageService.cms,
                                );
                                final media = StorageService.resolvePublicUrl(
                                  video['storage_path']?.toString(),
                                  bucket: StorageService.cms,
                                );
                                return SizedBox(
                                  width: 250,
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: media.isEmpty
                                          ? null
                                          : () async {
                                              final uri = Uri.tryParse(media);
                                              if (uri != null) {
                                                await launchUrl(
                                                  uri,
                                                  mode: LaunchMode.externalApplication,
                                                );
                                              }
                                            },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: thumb.isEmpty
                                                ? Container(
                                                    color: NileColors.surfaceVariant,
                                                    child: const Center(
                                                      child: Icon(Icons.play_circle_outline, size: 48),
                                                    ),
                                                  )
                                                : Image.network(
                                                    thumb,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image_outlined),
                                                    ),
                                                  ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Text(
                                              video['title']?.toString() ?? 'Video',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: NileTypography.titleSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

          ref.watch(testimonialsProvider).when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(NileSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customers', style: NileTypography.titleLarge),
                          const SizedBox(height: 8),
                          ...rows.take(3).map(
                                (t) => ListTile(
                                  title: Text(t['customer_name']?.toString() ?? ''),
                                  subtitle: Text(t['testimonial']?.toString() ?? ''),
                                ),
                              ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: NileSpacing.xxl)),
        ],
      ),
    );
  }

  static Widget _productGrid(List<Product> products) {
    if (products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: ProductCard.gridMaxCrossAxisExtent,
          mainAxisSpacing: NileSpacing.sm,
          crossAxisSpacing: NileSpacing.sm,
          childAspectRatio: ProductCard.gridChildAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: products[index]),
          childCount: products.length,
        ),
      ),
    );
  }

}

class _NileTropicalHeroCarousel extends StatefulWidget {
  const _NileTropicalHeroCarousel();

  @override
  State<_NileTropicalHeroCarousel> createState() => _NileTropicalHeroCarouselState();
}

class _NileTropicalHeroCarouselState extends State<_NileTropicalHeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  late final Future<Map<String, String>> _imagesFuture;

  static const _slides = [
    (
      slot: 'app_hero_1',
      fallback: 'assets/products/eco-shea-butter-250g.svg',
      heading: 'Nile Tropical Industries',
      text: 'A Ugandan enterprise creating natural, practical products for everyday life.',
    ),
    (
      slot: 'app_hero_2',
      fallback: 'assets/products/hibiscus-tea-150g.svg',
      heading: 'From Uganda, With Purpose',
      text: 'We bring together local inspiration, natural ingredients and thoughtful product development.',
    ),
    (
      slot: 'app_hero_3',
      fallback: 'assets/products/nile-sheabutter-lotion-apple-200ml.svg',
      heading: 'Natural Care For Everyday Living',
      text: 'Our growing range spans personal care, hygiene, wellness and botanical products.',
    ),
    (
      slot: 'app_hero_4',
      fallback: 'assets/products/shea-butter-mosquito-repellent-jelly-150g.svg',
      heading: 'Growing With Our Community',
      text: 'Nile Tropical Industries is building a modern Ugandan brand focused on quality, accessibility and value.',
    ),
  ];

  Future<Map<String, String>> _loadImages() async {
    final rows = await SupabaseService.client
        .from('website_media_slots')
        .select('slot_key,storage_path,is_active')
        .inFilter('slot_key', _slides.map((s) => s.slot).toList());
    final result = <String, String>{};
    for (final row in rows) {
      final path = row['storage_path']?.toString();
      if (row['is_active'] == true && path != null && path.isNotEmpty) {
        final url = StorageService.resolvePublicUrl(path, bucket: StorageService.cms);
        if (url.isNotEmpty) result[row['slot_key'].toString()] = url;
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        final customImages = snapshot.data ?? const <String, String>{};
        return SizedBox(
          height: 390,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              final customUrl = customImages[slide.slot];
              return Stack(
                fit: StackFit.expand,
                children: [
                  customUrl != null
                      ? Image.network(
                          customUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(slide.fallback, fit: BoxFit.cover),
                        )
                      : Image.asset(
                          slide.fallback,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: NileColors.primary,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported_outlined, color: Colors.white, size: 48),
                          ),
                        ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          NileColors.primary.withValues(alpha: 0.92),
                          NileColors.primary.withValues(alpha: 0.48),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.heading,
                              style: NileTypography.displaySmall.copyWith(color: Colors.white, height: 1.12),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.text,
                              style: NileTypography.bodyLarge.copyWith(
                                color: Colors.white.withValues(alpha: 0.94),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 22),
                            ElevatedButton(
                              onPressed: () => context.go('/shop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: NileColors.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
                              ),
                              child: Text('Explore our products', style: NileTypography.button),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 18,
                    child: Row(
                      children: List.generate(
                        _slides.length,
                        (dot) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: dot == _index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dot == _index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: NileColors.primaryContainer,
        borderRadius: NileRadius.borderMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: NileRadius.borderMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: NileColors.primary),
                const SizedBox(width: 8),
                Text(label, style: NileTypography.labelLarge.copyWith(color: NileColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
