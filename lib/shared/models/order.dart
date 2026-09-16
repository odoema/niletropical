/// Nile Tropical - Order Models
/// Copyright © Hon. Dr. Betty Udongo Pacutho

enum OrderStatus {
  newOrder,
  paymentPending,
  paymentConfirmed,
  orderConfirmed,
  processing,
  packed,
  readyForDispatch,
  dispatched,
  inTransit,
  arrivedAtDestination,
  outForDelivery,
  delivered,
  cancelled,
  refunded,
  deliveryFailed,
  returned,
  outOfStock,
}

enum PaymentStatus { unpaid, pending, paid, failed, refunded, partiallyPaid }

enum PaymentMethod { mtnMomo, airtelMoney, card, cashOnDelivery }

class Order {
  final String id;
  final String orderNumber;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final PaymentMethod? paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double discountTotal;
  final double total;
  final String currency;
  final String? customerName;
  final String? customerPhone;
  final Map<String, dynamic>? deliveryAddress;
  final List<OrderItem> items;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    this.discountTotal = 0,
    required this.total,
    this.currency = 'UGX',
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.items = const [],
    required this.createdAt,
  });
}

class OrderItem {
  final String id;
  final String productNameSnapshot;
  final String? variantNameSnapshot;
  final String? skuSnapshot;
  final double unitPrice;
  final double discount;
  final int quantity;
  final double lineTotal;

  const OrderItem({
    required this.id,
    required this.productNameSnapshot,
    this.variantNameSnapshot,
    this.skuSnapshot,
    required this.unitPrice,
    this.discount = 0,
    required this.quantity,
    required this.lineTotal,
  });
}
