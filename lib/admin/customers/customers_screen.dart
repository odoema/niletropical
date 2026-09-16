import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/customer_admin_service.dart';
import 'customer_detail_screen.dart';

// Nile tokens (match lib/core/theme/nile_colors.dart)
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

final _customersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, search) {
  return ref.watch(_customerAdminServiceProvider).listCustomers(search: search);
});

/// Admin → Customers list (Gap #2)
/// Route: /admin/customers
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String? _search;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() {
      _search =
          _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_customersProvider(_search));

    return Scaffold(
      backgroundColor: _Nile.surface,
      appBar: AppBar(
        backgroundColor: _Nile.primary,
        foregroundColor: Colors.white,
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_customersProvider(_search)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search name, phone or email',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _Nile.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _runSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    final status = (c['status'] as String?) ?? 'active';
                    final name = (c['full_name'] as String?) ?? '—';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _Nile.primary.withValues(alpha: 0.12),
                          foregroundColor: _Nile.primary,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            c['phone'],
                            if (c['email'] != null) c['email'],
                          ].whereType<String>().join(' · '),
                        ),
                        trailing: _StatusChip(status: status),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(
                                customerId: c['id'] as String,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'blocked' => _Nile.error,
      'inactive' => _Nile.warning,
      _ => _Nile.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
