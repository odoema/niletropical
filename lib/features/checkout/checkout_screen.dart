/// Nile Tropical - Checkout (server-side fee, idempotent order)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/providers/cart_provider.dart';
import '../../shared/services/order_service.dart';
import '../../shared/services/delivery_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/models/delivery.dart';
import '../../core/constants/payment_methods.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _paymentMethod = PaymentMethods.mtnMomo;
  String? _zoneId;

  bool _loading = false;

  List<DeliveryZone> _zones = const [];

  final _idempotencyKey = const Uuid().v4();

  double get _deliveryFee {
    final z = _zones.where((z) => z.id == _zoneId);

    return z.isEmpty ? 0 : z.first.deliveryFee;
  }

  @override
  void initState() {
    super.initState();

    DeliveryService.getZones().then((z) {
      if (mounted) {
        setState(() => _zones = z);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();

    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_zoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a delivery zone'),
        ),
      );

      return;
    }

    final cart = ref.read(cartProvider);

    if (cart.isEmpty) return;

    setState(() => _loading = true);

    try {
      final result = await OrderService.createOrder(
        cart: cart,
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty
            ? null
            : _email.text.trim(),
        address: _address.text.trim(),
        deliveryZoneId: _zoneId!,
        paymentMethod: _paymentMethod,
        notes: _notes.text.trim().isEmpty
            ? null
            : _notes.text.trim(),
        idempotencyKey: _idempotencyKey,
      );

      ref.read(cartProvider.notifier).clear();

      if (!mounted) return;

      final orderNumber =
          result['order_number'] as String? ?? 'NTI-XXXX';

      final total =
          (result['total'] as num?)?.toDouble() ??
              (cart.subtotal + _deliveryFee);

      if (PaymentMethods.isCod(_paymentMethod)) {
        context.go(
          '/confirmation',
          extra: {
            'orderNumber': orderNumber,
            'total': total,
            'paymentMethod': _paymentMethod,
          },
        );
      } else {
        context.go(
          '/pay/${result['order_id']}',
          extra: {
            'orderNumber': orderNumber,
            'total': total,
            'paymentMethod': _paymentMethod,
            'phone': _phone.text.trim(),
          },
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: const NileAppBar(
          title: 'Checkout',
        ),
        body: NileEmptyState(
          title: 'Cart is empty',
          actionLabel: 'Shop',
          onAction: () => context.go('/shop'),
        ),
      );
    }

    return Scaffold(
      appBar: const NileAppBar(
        title: 'Checkout',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(
            NileSpacing.md,
          ),
          children: [
            Text(
              'Contact',
              style: NileTypography.titleLarge,
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            NileTextField(
              controller: _name,
              label: 'Full name',
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            NileTextField(
              controller: _phone,
              label: 'Phone',
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().length < 9) {
                  return 'Valid phone required';
                }

                return null;
              },
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            NileTextField(
              controller: _email,
              label: 'Email (optional)',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(
              height: NileSpacing.lg,
            ),

            Text(
              'Delivery',
              style: NileTypography.titleLarge,
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            NileDropdown<String>(
              label: 'Delivery zone',
              value: _zoneId,
              items: _zones
                  .map(
                    (z) => DropdownMenuItem(
                      value: z.id,
                      child: Text(
                        '${z.name} — UGX ${z.deliveryFee.toStringAsFixed(0)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _zoneId = v);
              },
              validator: (v) {
                if (v == null) {
                  return 'Select a zone';
                }

                return null;
              },
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            NileTextField(
              controller: _address,
              label: 'Delivery address',
              maxLines: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            NileTextField(
              controller: _notes,
              label: 'Notes (optional)',
              maxLines: 2,
            ),

            const SizedBox(
              height: NileSpacing.lg,
            ),

            Text(
              'Payment',
              style: NileTypography.titleLarge,
            ),

            const SizedBox(
              height: NileSpacing.sm,
            ),

            ...PaymentMethods.all
                .map(
                  (m) => (
                    m,
                    PaymentMethods.labels[m]!,
                  ),
                )
                .map(
                  (m) => RadioListTile<String>(
                    value: m.$1,
                    groupValue: _paymentMethod,
                    onChanged: (v) {
                      if (v == null) return;

                      setState(
                        () => _paymentMethod = v,
                      );
                    },
                    title: Text(
                      m.$2,
                      style: NileTypography.bodyLarge,
                    ),
                    activeColor: NileColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

            const SizedBox(
              height: NileSpacing.lg,
            ),

            const SizedBox(
              height: NileSpacing.lg,
            ),

            NileCard(
              child: Column(
                children: [
                  _row(
                    'Subtotal',
                    cart.subtotal,
                  ),

                  if (_discount > 0)
                    _row(
                      'Discount',
                      -_discount,
                    ),

                  _row(
                    'Delivery',
                    _deliveryFee,
                  ),

                  const Divider(
                    height: 20,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: NileTypography.titleLarge,
                      ),

                      NilePrice(
                        amount: total,
                        style:
                            NileTypography.headlineSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: NileSpacing.lg,
            ),

            NileButton(
              label: PaymentMethods.isCod(
                _paymentMethod,
              )
                  ? 'Place order'
                  : 'Continue to payment',
              loading: _loading,
              onPressed: _placeOrder,
              icon: Icons.lock_outline,
            ),

            const SizedBox(
              height: NileSpacing.xl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    double amount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: NileTypography.bodyMedium,
          ),
          NilePrice(
            amount: amount,
            style: NileTypography.bodyLarge,
          ),
        ],
      ),
    );
  }
}