import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/customer_admin_service.dart';
import 'customer_detail_screen.dart';

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
      _search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
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
        elevation: 0,
        title: const Text(
          'Customers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh customers',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_customersProvider(_search)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: _Nile.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final field = TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _searchCtrl.clear();
                              _runSearch();
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                );
                final button = FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _Nile.primary,
                    minimumSize: const Size(110, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _runSearch,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Search'),
                );
                return compact
                    ? Column(
                        children: [field, const SizedBox(height: 8), SizedBox(width: double.infinity, child: button)],
                      )
                    : Row(
                        children: [Expanded(child: field), const SizedBox(width: 10), button],
                      );
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load customers: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    final status = (c['status'] as String?) ?? 'active';
                    final name = (c['full_name'] as String?) ?? '—';
                    final phone = c['phone']?.toString();
                    final email = c['email']?.toString();
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        dense: true,
                        minVerticalPadding: 10,
                        leading: CircleAvatar(
                          radius: 21,
                          backgroundColor: _Nile.primary.withValues(alpha: .10),
                          foregroundColor: _Nile.primary,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [phone, email].where((v) => v != null && v.isNotEmpty).join('  •  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: _StatusChip(status: status),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(customerId: c['id'] as String),
                          ),
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
