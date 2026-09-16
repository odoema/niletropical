/// Nile Tropical - Cart State Management
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/product.dart';

class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(const Cart());

  void addItem(Product product, ProductVariant variant, {int quantity = 1}) {
    state = state.addItem(product, variant, quantity: quantity);
  }

  void updateQuantity(String variantId, int quantity) {
    state = state.updateQuantity(variantId, quantity);
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
