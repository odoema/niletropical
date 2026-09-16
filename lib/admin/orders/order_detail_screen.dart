/// Admin order detail — fetch by ID
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState
    extends State<AdminOrderDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!Env.isConfigured) {
        _order = {
          'id': widget.orderId,
          'order_number': 'NTI-2026-001001',
          'status': 'processing',
          'payment_status': 'paid',
          'payment_method': 'mtn_momo',
          'total': 45000,
          'subtotal': 40000,
          'delivery_fee': 5000,
          'customer_name_snapshot': 'Demo Customer',
          'customer_phone_snapshot': '+256700000000',
          'delivery_address_snapshot': {
            'address_line': 'Nebbi Town',
          },
          'created_at': DateTime.now().toIso8601String(),
        };
      } else {
        final res = await SupabaseService.client
            .from('orders')
            .select('*, order_items(*)')
            .eq('id', widget.orderId)
            .maybeSingle();

        _order = res;

        if (_order == null) {
          _error = 'Order not found';
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      if (!Env.isConfigured) {
        setState(() {
          _order = {
            ..._order!,
            'status': status,
          };
        });
        return;
      }

      await SupabaseService.client.rpc(
        'set_order_status',
        params: {
          'p_order_id': widget.orderId,
          'p_status': status,
          'p_note': 'Updated by admin',
        },
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
        ),
      );
    }
  }

  String _statusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _paymentMethodLabel(String? method) {
    if (method == null || method.isEmpty) {
      return '—';
    }

    return method.replaceAll('_', ' ');
  }

  String _deliveryAddressLabel(
    Map<String, dynamic> order,
  ) {
    final address = order['delivery_address_snapshot'];

    if (address is Map<String, dynamic>) {
      final line = address['address_line'];

      if (line != null && line.toString().trim().isNotEmpty) {
        return line.toString();
      }

      final formatted = address['formatted_address'];

      if (formatted != null &&
          formatted.toString().trim().isNotEmpty) {
        return formatted.toString();
      }

      final city = address['city'];

      if (city != null && city.toString().trim().isNotEmpty) {
        return city.toString();
      }
    }

    return '—';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: NileLoadingState(),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: const NileAppBar(title: 'Order'),
        body: NileErrorState(
          message: _error ?? 'Not found',
          onRetry: _load,
        ),
      );
    }

    final o = _order!;

    final orderNumber =
        o['order_number'] as String? ?? 'Order';

    final status =
        o['status'] as String? ?? '';

    final paymentStatus =
        o['payment_status'] as String? ?? '';

    final paymentMethod =
        o['payment_method'] as String?;

    final customerName =
        o['customer_name_snapshot'] as String? ??
            '—';

    final customerPhone =
        o['customer_phone_snapshot'] as String? ??
            '';

    final total =
        (o['total'] as num?) ?? 0;

    return Scaffold(
      appBar: NileAppBar(
        title: orderNumber,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.camera_alt_outlined,
            ),
            onPressed: () => context.push(
              '/admin/orders/${widget.orderId}/pod',
            ),
            tooltip: 'Proof of delivery',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(
          NileSpacing.md,
        ),
        children: [
          Row(
            children: [
              NileStatusChip(
                status: status,
              ),
              const SizedBox(width: 8),
              NileBadge(
                label: paymentStatus,
                variant: paymentStatus == 'paid'
                    ? NileBadgeVariant.success
                    : NileBadgeVariant.warning,
              ),
            ],
          ),

          const SizedBox(
            height: NileSpacing.md,
          ),

          NileCard(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer',
                  style:
                      NileTypography.labelMedium,
                ),

                const SizedBox(height: 4),

                Text(
                  customerName,
                  style:
                      NileTypography.titleMedium,
                ),

                if (customerPhone.isNotEmpty)
                  Text(
                    customerPhone,
                    style:
                        NileTypography.bodyMedium,
                  ),

                const SizedBox(height: 12),

                Text(
                  'Delivery address',
                  style:
                      NileTypography.labelMedium,
                ),

                const SizedBox(height: 4),

                Text(
                  _deliveryAddressLabel(o),
                  style:
                      NileTypography.bodyMedium,
                ),

                const SizedBox(height: 12),

                Text(
                  'Payment',
                  style:
                      NileTypography.labelMedium,
                ),

                const SizedBox(height: 4),

                Text(
                  _paymentMethodLabel(
                    paymentMethod,
                  ),
                  style:
                      NileTypography.bodyLarge,
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style:
                          NileTypography.titleMedium,
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

          Text(
            'Update status',
            style:
                NileTypography.titleMedium,
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in [
                'order_confirmed',
                'processing',
                'packed',
                'ready_for_dispatch',
                'dispatched',
                'in_transit',
                'arrived_at_destination',
                'out_for_delivery',
                'delivered',
                'cancelled',
              ])
                ActionChip(
                  label: Text(
                    _statusLabel(s),
                  ),
                  onPressed: () =>
                      _setStatus(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}