/// Nile Tropical - Customer Orders
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/auth_service.dart';

class AccountOrdersScreen extends StatefulWidget {
  const AccountOrdersScreen({super.key});

  @override
  State<AccountOrdersScreen> createState() => _AccountOrdersScreenState();
}

class _AccountOrdersScreenState extends State<AccountOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Ownership chain: auth.uid() → customers.auth_user_id → customers.id
  /// → orders.customer_id. This is what the RLS policy in 014_rls.sql
  /// enforces server-side (orders_owner_read), and it's the join the
  /// updated create_order (016) now sets on new orders too. Matching by
  /// email was a fallback that broke as soon as a guest checkout used a
  /// different email from the account.
  Future<void> _load() async {
    if (!Env.isConfigured || AuthService.user == null) {
      setState(() {
        _loading = false;
        _error = AuthService.user == null
            ? 'Sign in to see your orders.'
            : 'Supabase is not configured.';
      });
      return;
    }
    try {
      final customer = await SupabaseService.client
          .from('customers')
          .select('id')
          .eq('auth_user_id', AuthService.user!.id)
          .maybeSingle();

      final query = SupabaseService.client
          .from('orders')
          .select('id, order_number, total, status, payment_status, created_at');

      // If a linked customer exists, filter by customer_id (matches RLS).
      // Otherwise fall back to email so orders placed under this email
      // before signup still surface. Never lose the user's history.
      final rows = customer != null
          ? await query
              .eq('customer_id', customer['id'])
              .order('created_at', ascending: false)
          : await query
              .eq('customer_email', AuthService.user!.email ?? '')
              .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'My orders'),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(
                  title: 'No orders loaded',
                  message: _error,
                  actionLabel: 'Shop',
                  onAction: () => context.go('/shop'),
                )
              : _orders.isEmpty
                  ? NileEmptyState(
                      title: 'No orders yet',
                      message: 'When you place an order it will appear here.',
                      icon: Icons.receipt_long_outlined,
                      actionLabel: 'Browse shop',
                      onAction: () => context.go('/shop'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(NileSpacing.md),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final o = _orders[i];
                        return ListTile(
                          title: Text(o['order_number']?.toString() ?? ''),
                          subtitle: Text('${o['status']} · ${o['payment_status']}'),
                          trailing: NilePrice(
                            amount: (o['total'] as num?)?.toDouble() ?? 0,
                          ),
                          onTap: () => context.go('/track/${o['order_number']}'),
                        );
                      },
                    ),
    );
  }
}
