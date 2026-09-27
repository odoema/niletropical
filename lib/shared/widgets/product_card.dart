import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../models/product.dart';
import '../services/storage_service.dart';
import 'nile_image.dart';

/// Standard Nile Tropical product card.
///
/// Card contract:
/// - one consistent surface, radius and spacing across shop/home/category grids
/// - image is edge-to-edge inside the clipped card
/// - image fills the allocated area with BoxFit.cover
/// - image loading/failure states never change the card geometry
/// - product name and price use a fixed content rhythm
class ProductCard extends StatelessWidget {
  /// Single grid contract used by home, shop and category screens.
  static const double gridMaxCrossAxisExtent = 240;
  static const double gridChildAspectRatio = 0.68;

  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final rawImageUrl = product.mainImageUrl;
    final imageUrl = StorageService.resolvePublicUrl(rawImageUrl);
    final price = product.variants.isNotEmpty ? product.variants.first.price : 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: NileRadius.borderLg,
        side: BorderSide(color: NileColors.border.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: () => context.push('/product/${product.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The grid gives the card a finite height. Expanded makes the
            // image consume all remaining space, so every card has the same
            // image footprint regardless of screen width.
            Expanded(
              child: _ProductImageFrame(
                imageUrl: imageUrl,
                product: product,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: SizedBox(
                height: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: NileTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    NilePrice(amount: price),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImageFrame extends StatelessWidget {
  const _ProductImageFrame({
    required this.imageUrl,
    required this.product,
  });

  final String imageUrl;
  final Product product;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _ImagePlaceholder(icon: Icons.spa_outlined);
    }

    final orderedImages = [...product.images]
      ..sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aCreated.compareTo(bCreated);
      });

    return _ResilientProductImage(
      urls: orderedImages
          .where((image) => image.url.isNotEmpty)
          .map((image) => StorageService.resolvePublicUrl(image.url))
          .toList(),
      fallbackUrl: imageUrl,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.icon = Icons.image_not_supported_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NileColors.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: NileColors.primary,
        size: 34,
      ),
    );
  }
}

class _ResilientProductImage extends StatefulWidget {
  const _ResilientProductImage({
    required this.urls,
    required this.fallbackUrl,
  });

  final List<String> urls;
  final String fallbackUrl;

  @override
  State<_ResilientProductImage> createState() => _ResilientProductImageState();
}

class _ResilientProductImageState extends State<_ResilientProductImage> {
  late List<String> _urls;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _resetUrls();
  }

  @override
  void didUpdateWidget(covariant _ResilientProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fallbackUrl != widget.fallbackUrl ||
        oldWidget.urls.length != widget.urls.length) {
      _resetUrls();
    }
  }

  void _resetUrls() {
    _urls = [
      ...widget.urls,
      if (!widget.urls.contains(widget.fallbackUrl)) widget.fallbackUrl,
    ];
    _index = 0;
  }

  void _failed() {
    if (_index + 1 < _urls.length && mounted) {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _urls.isNotEmpty ? _urls[_index] : widget.fallbackUrl;

    return ColoredBox(
      color: Colors.white,
      child: NileImage(
        key: ValueKey(url),
        url: url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        semanticLabel: 'Nile Tropical product image',
        memCacheWidth: 720,
        memCacheHeight: 720,
        onError: () {
          WidgetsBinding.instance.addPostFrameCallback((_) => _failed());
        },
      ),
    );
  }
}
