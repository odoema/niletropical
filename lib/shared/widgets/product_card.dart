import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../models/product.dart';
import '../services/storage_service.dart';

/// Standard Nile Tropical product card.
///
/// Card contract:
/// - one consistent surface, radius and spacing across shop/home/category grids
/// - image is edge-to-edge inside the clipped card
/// - image fills the allocated area with BoxFit.cover
/// - image loading/failure states never change the card geometry
/// - product name and price use a fixed content rhythm
class ProductCard extends StatefulWidget {
  /// Single grid contract used by home, shop and category screens.
  static const double gridMaxCrossAxisExtent = 240;
  static const double gridChildAspectRatio = 0.68;

  /// At or below this many units the card shows an "Only N left" nudge.
  static const int lowStockThreshold = 5;

  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  static const Duration _motion = Duration(milliseconds: 200);

  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final rawImageUrl = product.mainImageUrl;
    final imageUrl = StorageService.resolvePublicUrl(rawImageUrl);
    final price = product.variants.isNotEmpty ? product.variants.first.price : 0;

    // Hover lift is a transform + shadow only, so the grid geometry never
    // changes (card contract above).
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: _motion,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: NileRadius.borderLg,
          boxShadow: [
            BoxShadow(
              color: NileColors.primary.withValues(
                alpha: _hovered ? 0.16 : 0.06,
              ),
              blurRadius: _hovered ? 24 : 12,
              offset: Offset(0, _hovered ? 10 : 4),
            ),
          ],
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: NileRadius.borderLg,
            side: BorderSide(
              color: _hovered
                  ? NileColors.primary.withValues(alpha: 0.28)
                  : NileColors.border.withValues(alpha: 0.55),
            ),
          ),
          child: InkWell(
            onTap: () => context.push('/product/${product.slug}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The grid gives the card a finite height. Expanded makes the
                // image consume all remaining space, so every card has the
                // same image footprint regardless of screen width.
                Expanded(
                  child: ClipRect(
                    child: AnimatedScale(
                      scale: _hovered ? 1.04 : 1.0,
                      duration: _motion,
                      curve: Curves.easeOutCubic,
                      child: _ProductImageFrame(
                        imageUrl: imageUrl,
                        product: product,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: SizedBox(
                    height: 58,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: NileTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: _hovered
                                ? NileColors.primary
                                : NileColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (product.variants.isNotEmpty)
                              Flexible(
                                child: _StockLabel(
                                  quantity:
                                      product.variants.first.stockQuantity,
                                ),
                              ),
                            NilePrice(amount: price),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stock status with a dot indicator: out of stock, low stock, or in stock.
class _StockLabel extends StatelessWidget {
  const _StockLabel({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (quantity <= 0) {
      text = 'Out of stock';
      color = NileColors.error;
    } else if (quantity <= ProductCard.lowStockThreshold) {
      text = 'Only $quantity left';
      color = NileColors.warning;
    } else {
      text = 'In stock';
      color = NileColors.success;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NileTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
      child: Image.network(
        url,
        key: ValueKey(url),
        // Product photography should fill the card rather than float inside
        // a padded white box. The card itself supplies the clipping boundary.
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: NileColors.surfaceVariant,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _failed());
          return const _ImagePlaceholder();
        },
      ),
    );
  }
}
