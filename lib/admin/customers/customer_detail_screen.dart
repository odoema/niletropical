import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/customer_admin_service.dart';

class _Nile {
  static const primary = Color(0xFF233E85);
  static const success = Color(0xFF1F7A4D);
  static const warning = Color(0xFFB7791F);
  static const error = Color(0xFFB42318);
  static const surface = Color(0xFFF7F8FA);
}

final _customerAdminServiceProvider = Provider<CustomerAdminService>((ref) {
  return CustomerAdminService(Supabase.instance.client);
});

final _customerDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
  return ref.watch(_customerAdminServiceProvider).getCustomerDetail(id);
});

/// Admin → Customer detail
/// Route: /admin/customers/:id
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_customerDetailProvider(customerId));
    final money = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: _Nile.surface,
      appBar: AppBar(
        backgroundColor: _Nile.primary,
        foregroundColor: Colors.white,
        title: const Text('Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(_customerDetailProvider(customerId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Customer not found'));
          }

          final addresses =
              List<Map<String, dynamic>>.from(data['addresses'] ?? []);
          final orders =
              List<Map<String, dynamic>>.from(data['orders'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['full_name'] ?? '—',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text('Phone: ${data['phone'] ?? '—'}'),
                      if (data['email'] != null)
                        Text('Email: ${data['email']}'),
                      if (data['preferred_area'] != null)
                        Text('Area: ${data['preferred_area']}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Status: ${data['status']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: (status) async {
                              await ref
                                  .read(_customerAdminServiceProvider)
                                  .updateCustomerStatus(customerId, status);
                              ref.invalidate(
                                  _customerDetailProvider(customerId));
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'active', child: Text('Set Active')),
                              PopupMenuItem(
                                  value: 'inactive',
                                  child: Text('Set Inactive')),
                              PopupMenuItem(
                                  value: 'blocked',
                                  child: Text('Set Blocked')),
                            ],
                            child: Chip(
                              label: const Text('Change status'),
                              backgroundColor:
                                  _Nile.primary.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Addresses',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (addresses.isEmpty)
                const Text('No addresses')
              else
                ...addresses.map((a) {
                  final line = [
                    a['address_line'],
                    a['area'],
                    a['city'],
                    a['district'],
                  ]
                      .where((e) => e != null && e.toString().isNotEmpty)
                      .join(', ');
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.location_on_outlined,
                          color: _Nile.primary),
                      title: Text(line),
                      subtitle:
                          a['is_default'] == true ? const Text('Default') : null,
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Text('Recent orders',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (orders.isEmpty)
                const Text('No orders yet')
              else
                ...orders.map((o) {
                  final total = (o['total'] as num?)?.toDouble() ?? 0;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      title: Text(
                        o['order_number'] ?? o['id'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${o['status']} · ${o['payment_status']}'
                        '${o['payment_method'] != null ? ' · ${o['payment_method']}' : ''}',
                      ),
                      trailing: Text(
                        money.format(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _Nile.primary,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
