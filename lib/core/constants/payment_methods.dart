/// Canonical payment_method values — matches 006_orders.sql and the live
/// storefront contract. The Flutter client must never send aliases like
/// mtn_direct / cash; those are not on the enum.
library;

abstract final class PaymentMethods {
  static const mtnMomo = 'mtn_momo';
  static const airtelMoney = 'airtel_money';
  static const card = 'card';
  static const cashOnDelivery = 'cash_on_delivery';

  static const all = [mtnMomo, airtelMoney, card, cashOnDelivery];

  static const labels = {
    mtnMomo: 'MTN Mobile Money',
    airtelMoney: 'Airtel Money',
    card: 'Card',
    cashOnDelivery: 'Cash on delivery',
  };

  static bool isCod(String method) => method == cashOnDelivery;

  static bool isMobileMoney(String method) =>
      method == mtnMomo || method == airtelMoney;

  /// Map leftover UI aliases onto the enum so old routes do not crash.
  static String normalize(String? raw) {
    switch (raw) {
      case 'mtn_direct':
      case 'mtn':
        return mtnMomo;
      case 'airtel_direct':
      case 'airtel':
        return airtelMoney;
      case 'card_direct':
        return card;
      case 'cash':
      case 'cod':
        return cashOnDelivery;
      default:
        return all.contains(raw) ? raw! : mtnMomo;
    }
  }
}
