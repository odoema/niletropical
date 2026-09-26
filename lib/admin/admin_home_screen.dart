import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/nile_widgets.dart';
import '../shared/services/supabase_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _loading = true;
  String? _error;
  int _orders = 0;
  int _pendingDispatch = 0;
  int _lowStock = 0;
  double _revenue = 0;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Supabase is not configured.';
      });
      return;
    }

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toIso8601String();

      final orders = await SupabaseService.client
          .from('orders')
          .select('id,total,status')
          .gte('created_at', start);

      final rows = List<Map<String, dynamic>>.from(orders);
      final revenue = rows.fold<double>(
        0,
        (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
      );

      final pending = rows.where((row) {
        final status = row['status']?.toString();
        return status == 'ready_for_dispatch' ||
            status == 'packed' ||
            status == 'order_confirmed';
      }).length;

      final stockRows = await SupabaseService.client
          .from('product_variants')
          .select('stock_quantity,reorder_level,is_active')
          .eq('is_active', true);
      final low = List<Map<String, dynamic>>.from(stockRows).where((row) {
        final stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
        final reorder = (row['reorder_level'] as num?)?.toInt() ?? 5;
        return stock <= reorder;
      }).length;

      if (!mounted) return;
      setState(() {
        _orders = rows.length;
        _revenue = revenue;
        _pendingDispatch = pending;
        _lowStock = low;
        _loading = false;
        _error = null;
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
        title: 'Dashboard',
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loading ? null : _loadKpis,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadKpis,
        child: ListView(
          padding: const EdgeInsets.all(NileSpacing.md),
          children: [
            Text('Today', style: NileTypography.headlineSmall),
            const SizedBox(height: NileSpacing.sm),
            if (_error != null)
              NileCard(
                margin: const EdgeInsets.only(bottom: NileSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: NileColors.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Dashboard data unavailable: $_error')),
                  ],
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi('Orders', _loading ? '…' : '$_orders', Icons.receipt_long),
                _kpi(
                  'Revenue',
                  _loading ? '…' : 'UGX ${NumberFormat('#,##0').format(_revenue)}',
                  Icons.payments,
                ),
                _kpi('Pending dispatch', _loading ? '…' : '$_pendingDispatch', Icons.local_shipping),
                _kpi('Low stock', _loading ? '…' : '$_lowStock', Icons.warning_amber),
              ],
            ),
            const SizedBox(height: NileSpacing.xl),
            Text('Catalogue & content', style: NileTypography.titleLarge),
            const SizedBox(height: NileSpacing.sm),
            _action(
              context,
              'Products',
              'Manage products, pricing, variants and merchandising flags.',
              '/admin/products',
              Icons.inventory_2_outlined,
            ),
            _action(
              context,
              'Product Images',
              'Upload multiple images, choose the main image and remove old media.',
              '/admin/products/images',
              Icons.add_photo_alternate_outlined,
            ),
            _action(
              context,
              'CMS',
              'Manage website media, banners, pages, FAQs, testimonials and promotions.',
              '/admin/cms',
              Icons.dashboard_customize_outlined,
            ),
            const SizedBox(height: NileSpacing.lg),
            Text('Operations', style: NileTypography.titleLarge),
            const SizedBox(height: NileSpacing.sm),
            _action(context, 'Orders', 'Review and process customer orders.', '/admin/orders', Icons.receipt_long_outlined),
            _action(context, 'Inventory', 'Monitor stock and make adjustments.', '/admin/inventory', Icons.warehouse_outlined),
            _action(context, 'Delivery', 'Manage dispatch and deliveries.', '/admin/delivery', Icons.local_shipping_outlined),
            _action(context, 'Customers', 'View customer accounts and order history.', '/admin/customers', Icons.people_outline),
            _action(context, 'COD', 'Reconcile cash-on-delivery collections.', '/admin/finance/cod', Icons.payments_outlined),
            _action(context, 'Reports', 'Review business and operational reports.', '/admin/reports', Icons.bar_chart_outlined),
            _action(context, 'Analytics', 'See website visitors, traffic, live activity and conversion signals.', '/admin/analytics', Icons.insights_outlined),
            _action(context, 'Pricing', 'Review and approve pricing recommendations.', '/admin/pricing', Icons.price_change_outlined),
            _action(context, 'Notifications', 'Manage notification templates and delivery logs.', '/admin/notifications', Icons.notifications_outlined),
            _action(context, 'Audit Log', 'Review staff actions and administrative activity.', '/admin/audit', Icons.history_outlined),
            _action(context, 'Error Logs', 'Review production application failures, diagnostics and resolutions.', '/admin/errors', Icons.bug_report_outlined),
            _action(context, 'Management', 'Configure categories, coupons, delivery zones, partners and couriers.', '/admin/management', Icons.tune_outlined),
            _action(context, 'Settings', 'Control admin modules and project configuration.', '/admin/settings', Icons.settings_outlined),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon) {
    return SizedBox(
      width: 180,
      child: NileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: NileColors.primary, size: 22),
            const SizedBox(height: 8),
            Text(value, style: NileTypography.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: NileTypography.caption),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String label,
    String subtitle,
    String route,
    IconData icon,
  ) {
    return NileCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => context.go(route),
      child: Row(
        children: [
          Icon(icon, color: NileColors.primary, size: 26),
          const SizedBox(width: NileSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: NileTypography.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: NileTypography.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
