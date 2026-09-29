/// Nile Tropical - Checkout (server-side fee, idempotent order)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/providers/cart_provider.dart';
import '../../shared/services/order_service.dart';
import '../../shared/services/delivery_service.dart';
import '../../shared/services/location_search_service.dart';
import '../../admin/delivery/nile_delivery_map.dart';
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
  final _locationCtrl = TextEditingController();
  final _notes = TextEditingController();
  final _originCtrl = TextEditingController(text: 'Kampala, Uganda');
  Timer? _locationDebounce;
  GeoPlace? _origin;
  GeoPlace? _destination;
  RouteEstimate? _route;
  Map<String, dynamic>? _quote;
  List<GeoPlace> _locationResults = const [];
  bool _searchingLocation = false;
  bool _calculatingDelivery = false;
  String _paymentMethod = PaymentMethods.mtnMomo;
  String? _zoneId;

  bool _loading = false;

  List<DeliveryZone> _zones = const [];

  final _idempotencyKey = const Uuid().v4();

  double get _deliveryFee {
    final quoted = (_quote?['delivery_fee'] as num?)?.toDouble();
    if (quoted != null) return quoted;

    // Keep the pre-quote display aligned with the production pricing model.
    // The order cannot be placed until the authoritative server quote exists.
    return 0;
  }

  @override
  void initState() {
    super.initState();

    DeliveryService.getZones().then((z) {
      if (mounted) {
        setState(() {
          _zones = z;
          if (_zoneId == null && z.isNotEmpty) {
            _zoneId = z.first.id;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _locationCtrl.dispose();
    _notes.dispose();
    _originCtrl.dispose();
    _locationDebounce?.cancel();

    super.dispose();
  }

  void _searchDestination(String value) {
    _locationDebounce?.cancel();
    setState(() {
      _destination = null;
      _route = null;
      _quote = null;
    });
    if (value.trim().length < 3) {
      setState(() => _locationResults = const []);
      return;
    }
    _locationDebounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searchingLocation = true);
      try {
        final results = await LocationSearchService.search(value);
        if (mounted) setState(() => _locationResults = results);
      } catch (_) {
        if (mounted) setState(() => _locationResults = const []);
      } finally {
        if (mounted) setState(() => _searchingLocation = false);
      }
    });
  }

  Future<void> _calculateDelivery() async {
    if (_zoneId == null || _destination == null) return;
    setState(() => _calculatingDelivery = true);
    try {
      var origin = _origin;
      if (origin == null) {
        final results = await LocationSearchService.search(_originCtrl.text);
        if (results.isEmpty) throw StateError('Dispatch origin could not be located.');
        origin = results.first;
      }
      final route = await LocationSearchService.route(
        origin: origin,
        destination: _destination!,
      );
      final quote = await DeliveryService.quoteDelivery(
        deliveryZoneId: _zoneId!,
        distanceKm: route.distanceKm,
        durationMinutes: route.durationMinutes,
      );
      if (!mounted) return;
      setState(() {
        _origin = origin;
        _route = route;
        _quote = quote;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not calculate delivery: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _calculatingDelivery = false);
    }
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

    if (_destination == null || _route == null || _quote == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select your delivery location and calculate the delivery quote first.')));
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
        deliveryDistanceKm: _route!.distanceKm,
        deliveryDurationMinutes: _route!.durationMinutes,
        deliveryOrigin: {'name': _origin!.name, 'latitude': _origin!.latitude, 'longitude': _origin!.longitude},
        deliveryDestination: {'name': _destination!.name, 'latitude': _destination!.latitude, 'longitude': _destination!.longitude},
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

    final total = cart.subtotal + _deliveryFee;

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
                      child: Text(z.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _zoneId = v;
                  _quote = null;
                });
              },
              validator: (v) {
                if (v == null) {
                  return 'Select a zone';
                }

                return null;
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Delivery is calculated from the active Nile Tropical pricing rule using the road route.',
              style: NileTypography.bodySmall,
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
            const SizedBox(height: NileSpacing.sm),
            Text('Delivery location', style: NileTypography.titleLarge),
            const SizedBox(height: 6),
            Text('Search your delivery location. We use the road route to calculate the delivery charge.', style: NileTypography.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              onChanged: _searchDestination,
              decoration: InputDecoration(
                hintText: 'Search address or landmark',
                prefixIcon: const Icon(Icons.location_searching_rounded),
                suffixIcon: _searchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_locationResults.isNotEmpty)
              Card(
                child: Column(
                  children: _locationResults.map((p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: NileColors.primary),
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => setState(() {
                      _destination = p;
                      _locationCtrl.text = p.name;
                      _address.text = p.name;
                      _locationResults = const [];
                    }),
                  )).toList(),
                ),
              ),
            if (_destination != null) ...[
              const SizedBox(height: 10),
              if (_origin != null && _route != null)
                NileDeliveryMap(
                  origin: _origin!,
                  destination: _destination!,
                  route: _route,
                  height: 280,
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _calculatingDelivery || _zoneId == null ? null : _calculateDelivery,
                  icon: _calculatingDelivery
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate_rounded),
                  label: Text(_calculatingDelivery ? 'Calculating route…' : 'Calculate delivery quote'),
                ),
              ),
            ],
            if (_quote != null && _route != null) ...[
              const SizedBox(height: 10),
              NileCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _route!.distanceKm.toStringAsFixed(1) + ' km • ' +
                              _route!.durationMinutes.ceil().toString() + ' min',
                          style: NileTypography.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text('Road distance and estimated driving time', style: NileTypography.bodySmall),
                      ],
                    ),
                    NilePrice(
                      amount: (_quote!['delivery_fee'] as num).toDouble(),
                      style: NileTypography.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: NileSpacing.sm),
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
            const SizedBox(height: NileSpacing.xs),
            Text(
              'Choose how you would like to pay. Your order will keep the same secure payment flow.',
              style: NileTypography.bodySmall,
            ),
            const SizedBox(height: NileSpacing.sm),
            _paymentOption(
              method: PaymentMethods.mtnMomo,
              title: 'MTN Mobile Money',
              subtitle: 'Pay directly with MTN Mobile Money.',
              icon: Icons.phone_android_rounded,
              brands: const ['MTN'],
            ),
            const SizedBox(height: NileSpacing.sm),
            _paymentOption(
              method: PaymentMethods.airtelMoney,
              title: 'Airtel Money',
              subtitle: 'Payment provider is not enabled yet.',
              icon: Icons.phone_android_rounded,
              brands: const ['Airtel'],
              enabled: false,
              note: 'Coming soon — this option is not available for live checkout yet.',
            ),
            const SizedBox(height: NileSpacing.sm),
            _paymentOption(
              method: PaymentMethods.card,
              title: 'Card & international payment',
              subtitle: 'Card provider is not enabled yet.',
              icon: Icons.credit_card_rounded,
              brands: const [
                'VISA',
                'Mastercard',
                'Maestro',
                'Visa Electron',
                'PayPal',
                'Skrill',
              ],
              enabled: false,
              note: 'Coming soon — no card payment provider is enabled for live checkout yet.',
            ),
            const SizedBox(height: NileSpacing.sm),
            Text(
              'Live payment methods: MTN Mobile Money and Cash on delivery. Airtel Money and card payments will appear when their providers are enabled.',
              style: NileTypography.bodySmall,
            ),
            const SizedBox(height: NileSpacing.sm),
            _paymentOption(
              method: PaymentMethods.cashOnDelivery,
              title: 'Cash on delivery',
              subtitle: 'Pay when your order is delivered.',
              icon: Icons.payments_outlined,
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

  Widget _paymentOption({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
    List<String> brands = const [],
    String? note,
    bool enabled = true,
  }) {
    final selected = _paymentMethod == method;

    return NileCard(
      padding: EdgeInsets.zero,
      child: RadioListTile<String>(
        value: method,
        groupValue: _paymentMethod,
        onChanged: enabled
            ? (value) {
                if (value == null) return;
                setState(() => _paymentMethod = value);
              }
            : null,
        activeColor: NileColors.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NileSpacing.sm,
          vertical: NileSpacing.xs,
        ),
        secondary: Icon(
          icon,
          color: selected ? NileColors.primary : NileColors.textSecondary,
        ),
        title: Text(
          title,
          style: NileTypography.bodyLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: NileTypography.bodySmall),
              if (brands.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: brands
                      .map(
                        (brand) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: NileColors.surface,
                            borderRadius: NileRadius.borderSm,
                            border: Border.all(color: NileColors.border),
                          ),
                          child: Text(
                            brand,
                            style: NileTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note, style: NileTypography.caption),
              ],
            ],
          ),
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
