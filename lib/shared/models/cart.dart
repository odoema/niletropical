/// Nile Tropical - Cart Models
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'product.dart';

class CartItem {
  final Product product;
  final ProductVariant variant;
  int quantity;

  CartItem({
    required this.product,
    required this.variant,
    this.quantity = 1,
  });

  double get unitPrice => variant.price;
  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      variant: variant,
      quantity: quantity ?? this.quantity,
    );
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.lineTotal);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  Cart addItem(Product product, ProductVariant variant, {int quantity = 1}) {
    final existingIndex = items.indexWhere(
      (item) => item.variant.id == variant.id,
    );

    if (existingIndex >= 0) {
      final updated = List<CartItem>.from(items);
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + quantity,
      );
      return Cart(items: updated);
    }

    return Cart(
      items: [
        ...items,
        CartItem(product: product, variant: variant, quantity: quantity),
      ],
    );
  }

  Cart updateQuantity(String variantId, int quantity) {
    if (quantity <= 0) {
      return removeItem(variantId);
    }
    final updated = items.map((item) {
      if (item.variant.id == variantId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    return Cart(items: updated);
  }

  Cart removeItem(String variantId) {
    return Cart(
      items: items.where((item) => item.variant.id != variantId).toList(),
    );
  }

  Cart clear() => const Cart();
}
