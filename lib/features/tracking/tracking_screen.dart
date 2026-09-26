/// Customer order tracking.
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/order_service.dart';

class TrackingScreen extends StatefulWidget {
  final String? orderNumber;
  final String? phone;

  const TrackingScreen({
    super.key,
    this.orderNumber,
    this.phone,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _orderController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orderController.text = widget.orderNumber ?? '';
    _phoneController.text = widget.phone ?? '';

    if (widget.orderNumber != null && widget.phone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _track());
    }
  }

  @override
  void dispose() {
    _orderController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    final order = _orderController.text.trim();
    final phone = _phoneController.text.trim();

    if (order.isEmpty || phone.isEmpty) {
      setState(() {
        _error = 'Enter your order number and the phone number used at checkout.';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final data = await OrderService.trackOrder(
        orderNumber: order,
        phone: phone,
      );

      if (!mounted) return;

      if (data == null || data['found'] != true) {
        setState(() {
          _error = 'We could not find that order. Check the order number and phone number.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _result = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'We could not load this order right now. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shipment = _result?['shipment'];
    return Scaffold(
      appBar: const NileAppBar(title: 'Track order'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          NileTextField(
            controller: _orderController,
            label: 'Order number',
            hint: 'NTI-2026-000123',
          ),
          const SizedBox(height: NileSpacing.sm),
          NileTextField(
            controller: _phoneController,
            label: 'Phone used at checkout',
            hint: '07XX XXX XXX',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: NileSpacing.md),
          NileButton(
            label: 'Track',
            loading: _loading,
            onPressed: _track,
            icon: Icons.search,
          ),
          if (_error != null) ...[
            const SizedBox(height: NileSpacing.md),
            NileCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: NileColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: NileTypography.bodyMedium.copyWith(
                        color: NileColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: NileSpacing.lg),
            NileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _result!['order_number']?.toString() ?? '',
                    style: NileTypography.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  NileStatusChip(
                    status: _result!['status']?.toString() ?? 'unknown',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payment: ${_result!['payment_status'] ?? 'unknown'}',
                    style: NileTypography.bodyMedium,
                  ),
                  if (_result!['total'] is num) ...[
                    const SizedBox(height: 6),
                    NilePrice(
                      amount: (_result!['total'] as num).toDouble(),
                    ),
                  ],
                ],
              ),
            ),
            if (shipment is Map && shipment.isNotEmpty) ...[
              const SizedBox(height: NileSpacing.md),
              NileCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: NileColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery', style: NileTypography.titleSmall),
                          const SizedBox(height: 3),
                          Text(
                            shipment['status']?.toString() ?? 'Shipment created',
                            style: NileTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: NileSpacing.md),
            Text('Timeline', style: NileTypography.titleMedium),
            const SizedBox(height: NileSpacing.sm),
            ..._buildTimeline(_result!['timeline'] as List? ?? const []),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(List timeline) {
    if (timeline.isEmpty) {
      return [
        const Text('No status updates have been recorded yet.'),
      ];
    }

    return timeline.map((entry) {
      final m = Map<String, dynamic>.from(entry as Map);
      final status = m['status']?.toString() ?? 'update';
      final note = m['note']?.toString();
      final created = m['created_at']?.toString();

      return Padding(
        padding: const EdgeInsets.only(bottom: NileSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle,
              color: NileColors.success,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status, style: NileTypography.titleSmall),
                  if (note != null && note.isNotEmpty)
                    Text(note, style: NileTypography.bodyMedium),
                  if (created != null && created.isNotEmpty)
                    Text(created, style: NileTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
