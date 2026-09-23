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

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NileColors.border.withOpacity(.55)),
      ),
      child: InkWell(
        onTap: () => context.push('/product/${product.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.45,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => Container(
                            color: NileColors.surfaceVariant,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: NileColors.surfaceVariant,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: NileColors.textTertiary,
                              size: 28,
                            ),
                          ),
                        )
                      : Container(
                          color: NileColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.spa_outlined,
                            color: NileColors.primary,
                            size: 34,
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
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
                  const SizedBox(height: 6),
                  NilePrice(amount: price),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
