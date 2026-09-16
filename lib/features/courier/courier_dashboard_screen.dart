/// Nile Tropical - Courier Dashboard
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/auth_service.dart';

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key, this.history = false});
  final bool history;

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Filter shipments to the signed-in courier explicitly.
  ///
  /// The RLS policy `shipments_courier_read` in 014_rls.sql restricts a
  /// courier to their own shipments, but never rely on RLS as the only
  /// business rule — one policy change and unrelated shipments start
  /// flowing to every device. The chain is:
  ///     auth.uid() → couriers.auth_user_id → couriers.id
  ///                → shipments.courier_id
  Future<void> _load() async {
    if (!Env.isConfigured || AuthService.user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in as a courier to see assignments.';
      });
      return;
    }
    try {
      final courier = await SupabaseService.client
          .from('couriers')
          .select('id')
          .eq('auth_user_id', AuthService.user!.id)
          .maybeSingle();

      if (courier == null) {
        // A signed-in user with courier role but no couriers row.
        // Show a clear message rather than leaking other couriers' data.
        setState(() {
          _loading = false;
          _error =
              'No courier profile linked to this account. Ask a manager to link you in the couriers table.';
        });
        return;
      }

      var query = SupabaseService.client
          .from('shipments')
          .select()
          .eq('courier_id', courier['id']);
      query = widget.history
          ? query.eq('status', 'delivered')
          : query.neq('status', 'delivered');

      final rows = await query.order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
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
      appBar: NileAppBar(
        title: widget.history ? 'Delivery history' : 'My runs',
      ),
      body: _loading
          ? const NileLoadingState()
          : _error != null || _rows.isEmpty
              ? NileEmptyState(
                  title: widget.history
                      ? 'No completed runs'
                      : 'No assigned shipments',
                  message: _error ??
                      (widget.history
                          ? 'Completed deliveries will show here.'
                          : 'When a manager assigns a shipment it will appear here.'),
                  icon: Icons.local_shipping_outlined,
                  actionLabel: 'Refresh',
                  onAction: _load,
                )
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final s = _rows[i];
                    return ListTile(
                      title: Text(s['id']?.toString() ?? ''),
                      subtitle: Text(s['status']?.toString() ?? ''),
                      onTap: () => context.go('/courier/shipment/${s['id']}'),
                    );
                  },
                ),
    );
  }
}
