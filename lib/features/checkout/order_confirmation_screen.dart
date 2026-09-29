/// Order confirmation
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderNumber,
    required this.total,
    required this.paymentMethod,
    this.phone,
    this.subtotal,
    this.deliveryFee,
    this.distanceKm,
    this.durationMinutes,
    this.pickupLabel,
    this.dropoffLabel,
    this.deliveryZone,
  });

  final String orderNumber;
  final double total;
  final String paymentMethod;
  final String? phone;
  final double? subtotal;
  final double? deliveryFee;
  final double? distanceKm;
  final double? durationMinutes;
  final String? pickupLabel;
  final String? dropoffLabel;
  final String? deliveryZone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NileSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: NileColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 48, color: NileColors.success),
              ),
              const SizedBox(height: NileSpacing.lg),
              Text('Order placed', style: NileTypography.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: NileSpacing.sm),
              Text(
                'Thank you. We\'ll notify you as your order progresses.',
                style: NileTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NileSpacing.xl),
              NileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Order receipt', style: NileTypography.titleMedium),
                    const SizedBox(height: NileSpacing.sm),
                    _line('Order number', orderNumber),
                    if (deliveryZone != null) _line('Delivery area', deliveryZone!),
                    if (pickupLabel != null) _line('From', pickupLabel!),
                    if (dropoffLabel != null) _line('To', dropoffLabel!),
                    if (distanceKm != null || durationMinutes != null)
                      _line(
                        'Route',
                        [
                          if (distanceKm != null) distanceKm!.toStringAsFixed(1) + ' km',
                          if (durationMinutes != null) durationMinutes!.ceil().toString() + ' min',
                        ].join(' • '),
                      ),
                    const Divider(height: 20),
                    if (subtotal != null) _line('Products', null, amount: subtotal!),
                    if (deliveryFee != null) _line('Delivery', null, amount: deliveryFee!),
                    if (subtotal != null || deliveryFee != null) const Divider(height: 20),
                    _line('Total paid', null, amount: total),
                    _line('Paid via', paymentMethod.replaceAll('_', ' ')),
                  ],
                ),
              ),
              const Spacer(),
              NileButton(
                label: 'Track order',
                icon: Icons.local_shipping_outlined,
                onPressed: () => context.go(
                  '/track/$orderNumber',
                  extra: {'phone': phone},
                ),
              ),
              const SizedBox(height: NileSpacing.sm),
              NileOutlinedButton(
                label: 'Continue shopping',
                onPressed: () => context.go('/shop'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String? value, {double? amount}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: NileTypography.bodyMedium),
          if (amount != null)
            NilePrice(amount: amount)
          else
            Text(value ?? '', style: NileTypography.titleSmall),
        ],
      ),
    );
  }
}
