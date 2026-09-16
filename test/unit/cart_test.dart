import 'package:flutter_test/flutter_test.dart';
import 'package:nile_tropical/shared/models/cart.dart';
import 'package:nile_tropical/shared/models/product.dart';

void main() {
  final product = Product(
    id: 'p1',
    name: 'Shea Butter',
    slug: 'shea-butter',
    createdAt: DateTime(2026, 1, 1),
    variants: const [
      ProductVariant(
        id: 'v1',
        productId: 'p1',
        sku: 'SB-250',
        name: '250g',
        price: 10000,
        stockQuantity: 10,
      ),
    ],
  );
  final variant = product.variants.first;

  test('empty cart', () {
    const cart = Cart();
    expect(cart.isEmpty, true);
    expect(cart.subtotal, 0);
    expect(cart.itemCount, 0);
  });

  test('add item increases quantity and subtotal', () {
    var cart = const Cart().addItem(product, variant, quantity: 2);
    expect(cart.itemCount, 2);
    expect(cart.subtotal, 20000);
    cart = cart.addItem(product, variant, quantity: 1);
    expect(cart.itemCount, 3);
    expect(cart.subtotal, 30000);
  });

  test('update and remove', () {
    var cart = const Cart().addItem(product, variant, quantity: 3);
    cart = cart.updateQuantity('v1', 1);
    expect(cart.itemCount, 1);
    cart = cart.removeItem('v1');
    expect(cart.isEmpty, true);
  });
}
