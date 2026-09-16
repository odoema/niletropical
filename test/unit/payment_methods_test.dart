import 'package:flutter_test/flutter_test.dart';
import 'package:nile_tropical/core/constants/payment_methods.dart';

void main() {
  test('normalizes legacy aliases to enum values', () {
    expect(PaymentMethods.normalize('mtn_direct'), PaymentMethods.mtnMomo);
    expect(PaymentMethods.normalize('cash'), PaymentMethods.cashOnDelivery);
    expect(PaymentMethods.normalize('airtel'), PaymentMethods.airtelMoney);
    expect(PaymentMethods.normalize('mtn_momo'), PaymentMethods.mtnMomo);
  });

  test('COD and momo helpers', () {
    expect(PaymentMethods.isCod('cash_on_delivery'), true);
    expect(PaymentMethods.isMobileMoney('mtn_momo'), true);
    expect(PaymentMethods.isMobileMoney('card'), false);
  });
}
