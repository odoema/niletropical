/// Admin order list — real query path with filters
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';

class AdminOrderListScreen extends StatefulWidget {
  const AdminOrderListScreen({super.key});

  @override
  State<AdminOrderListScreen> createState() => _AdminOrderListScreenState();
}

class _AdminOrderListScreenState extends State<AdminOrderListScreen> {
  String? _statusFilter;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
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
        // Dev sample
        _orders = [
          {
            'id': '1',
            'order_number': 'NTI-2026-001001',
            'status': 'new_order',
            'payment_status': 'paid',
            'total': 45000,
            'customer_name_snapshot': 'Demo Customer',
            'customer_phone_snapshot': '+256700000000',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': '2',
            'order_number': 'NTI-2026-001002',
            'status': 'processing',
            'payment_status': 'unpaid',
            'total': 12000,
            'customer_name_snapshot': 'Jane A.',
            'customer_phone_snapshot': '+256700000001',
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 3))
                .toIso8601String(),
          },
        ];
      } else {
        var q = SupabaseService.client
            .from('orders')
            .select(
              'id, order_number, status, payment_status, total, '
              'customer_name_snapshot, customer_phone_snapshot, created_at',
            );

        if (_statusFilter != null) {
          q = q.eq('status', _statusFilter!);
        }

        final res = await q.order('created_at', ascending: false).limit(50);

        _orders = List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Orders'),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: NileSpacing.md,
              vertical: 8,
            ),
            child: Row(
              children: [
                for (final s in [
                  null,
                  'new_order',
                  'payment_pending',
                  'payment_confirmed',
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        s == null ? 'All' : _statusLabel(s),
                      ),
                      selected: _statusFilter == s,
                      onSelected: (_) {
                        setState(() => _statusFilter = s);
                        _load();
                      },
                      selectedColor: NileColors.primaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const NileLoadingState()
                : _error != null
                    ? NileErrorState(
                        message: _error,
                        onRetry: _load,
                      )
                    : _orders.isEmpty
                        ? const NileEmptyState(
                            title: 'No orders',
                            icon: Icons.receipt_long_outlined,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(
                                NileSpacing.md,
                              ),
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final o = _orders[i];

                                final customerName =
                                    o['customer_name_snapshot']
                                            as String? ??
                                        'Unknown customer';

                                final orderNumber =
                                    o['order_number'] as String? ?? '';

                                final status =
                                    o['status'] as String? ?? '';

                                final total =
                                    (o['total'] as num?) ?? 0;

                                return NileCard(
                                  onTap: () => context.push(
                                    '/admin/orders/${o['id']}',
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              orderNumber,
                                              style:
                                                  NileTypography.titleSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              customerName,
                                              style:
                                                  NileTypography.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          NileStatusChip(
                                            status: status,
                                          ),
                                          const SizedBox(height: 4),
                                          NilePrice(
                                            amount: total,
                                            style:
                                                NileTypography.titleSmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}