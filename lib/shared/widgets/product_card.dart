import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../models/product.dart';
import '../services/storage_service.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final rawImageUrl = product.mainImageUrl;
    final imageUrl = StorageService.resolvePublicUrl(rawImageUrl);
    final price = product.variants.isNotEmpty ? product.variants.first.price : 0;

    return NileCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/product/${product.slug}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: NileColors.surfaceVariant),
                    errorWidget: (_, __, ___) => Container(
                      color: NileColors.surfaceVariant,
                      child: const Icon(Icons.image_not_supported_outlined, color: NileColors.textTertiary),
                    ),
                  )
                : Container(
                    color: NileColors.surfaceVariant,
                    child: const Icon(Icons.spa, color: NileColors.primary, size: 40),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(NileSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: NileTypography.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                NilePrice(amount: price),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
