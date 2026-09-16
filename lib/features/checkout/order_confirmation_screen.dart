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
  });

  final String orderNumber;
  final double total;
  final String paymentMethod;

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
                  children: [
                    _line('Order number', orderNumber),
                    _line('Total', null, amount: total),
                    _line('Payment', paymentMethod.replaceAll('_', ' ')),
                  ],
                ),
              ),
              const Spacer(),
              NileButton(
                label: 'Track order',
                icon: Icons.local_shipping_outlined,
                onPressed: () => context.go('/track/$orderNumber'),
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
