/// Nile Tropical - Cart Screen
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/providers/cart_provider.dart';
import '../../shared/models/cart.dart';
import '../../shared/services/storage_service.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: const NileAppBar(title: 'Cart'),
      body: cart.isEmpty
          ? NileEmptyState(
              title: 'Your cart is empty',
              message: 'Browse the shop to add products.',
              icon: Icons.shopping_bag_outlined,
              actionLabel: 'Go to shop',
              onAction: () => context.go('/shop'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(NileSpacing.md),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: NileSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartLine(item: item);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(NileSpacing.md),
                  decoration: const BoxDecoration(
                    color: NileColors.surface,
                    border: Border(top: BorderSide(color: NileColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal', style: NileTypography.titleMedium),
                            NilePrice(amount: cart.subtotal),
                          ],
                        ),
                        const SizedBox(height: NileSpacing.sm),
                        NileButton(
                          label: 'Checkout',
                          icon: Icons.lock_outline,
                          onPressed: () => context.push('/checkout'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NileCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CartProductImage(item: item),
          const SizedBox(width: NileSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.brand.toUpperCase(), style: NileTypography.labelSmall.copyWith(color: NileColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.9)),
                const SizedBox(height: 2),
                Text(item.product.name, style: NileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.variant.name, style: NileTypography.bodySmall.copyWith(color: NileColors.textSecondary)),
                const SizedBox(height: 4),
                NilePrice(amount: item.lineTotal, style: NileTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyBtn(
                      icon: Icons.remove,
                      onTap: () {
                        if (item.quantity <= 1) {
                          ref.read(cartProvider.notifier).removeItem(item.variant.id);
                        } else {
                          ref.read(cartProvider.notifier).updateQuantity(item.variant.id, item.quantity - 1);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity}', style: NileTypography.titleSmall),
                    ),
                    _QtyBtn(
                      icon: Icons.add,
                      onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.variant.id, item.quantity + 1),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: NileColors.error, size: 20),
                      onPressed: () => ref.read(cartProvider.notifier).removeItem(item.variant.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NileColors.surfaceVariant,
      borderRadius: NileRadius.borderSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: NileRadius.borderSm,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: NileColors.textPrimary),
        ),
      ),
    );
  }
}

class _CartProductImage extends StatelessWidget {
  const _CartProductImage({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final resolved = StorageService.resolvePublicUrl(item.product.mainImageUrl);
    return ClipRRect(
      borderRadius: NileRadius.borderSm,
      child: Container(
        width: 88,
        height: 88,
        color: NileColors.surfaceVariant,
        alignment: Alignment.center,
        child: resolved.isEmpty
            ? const Icon(Icons.spa_outlined, color: NileColors.primary, size: 30)
            : Image.network(
                resolved,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: NileColors.primary, size: 30),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
      ),
    );
  }
}
