/// Nile Tropical - Cart State Management
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/product.dart';

class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(const Cart());

  void addItem(Product product, ProductVariant variant, {int quantity = 1}) {
    if (variant.stockQuantity <= 0) return;
    final existing = state.items.where((item) => item.variant.id == variant.id);
    final current = existing.isEmpty ? 0 : existing.first.quantity;
    final capped = (current + quantity).clamp(1, variant.stockQuantity);
    state = state.removeItem(variant.id).addItem(
      product,
      variant,
      quantity: capped,
    );
  }

  void updateQuantity(String variantId, int quantity) {
    final existing = state.items.where((item) => item.variant.id == variantId);
    if (existing.isEmpty) return;
    final maxStock = existing.first.variant.stockQuantity;
    state = state.updateQuantity(
      variantId,
      quantity.clamp(1, maxStock),
    );
  }

  void removeItem(String variantId) {
    state = state.removeItem(variantId);
  }

  void clear() {
    state = state.clear();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  return CartNotifier();
});

/// Convenience providers
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});
