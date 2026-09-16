import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/nile_widgets.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Dashboard'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          Text('Today', style: NileTypography.headlineSmall),
          const SizedBox(height: NileSpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi('Orders', '—', Icons.receipt_long),
              _kpi('Revenue', '—', Icons.payments),
              _kpi('Pending dispatch', '—', Icons.local_shipping),
              _kpi('Low stock', '—', Icons.warning_amber),
            ],
          ),
          const SizedBox(height: NileSpacing.xl),
          Text('Quick actions', style: NileTypography.titleLarge),
          const SizedBox(height: NileSpacing.sm),
          _action(context, 'Orders', '/admin/orders', Icons.receipt_long_outlined),
          _action(context, 'Products', '/admin/products', Icons.inventory_2_outlined),
          _action(context, 'Inventory', '/admin/inventory', Icons.warehouse_outlined),
          _action(context, 'Delivery', '/admin/delivery', Icons.local_shipping_outlined),
          _action(context, 'CMS', '/admin/cms', Icons.article_outlined),
          _action(context, 'Reports', '/admin/reports', Icons.bar_chart_outlined),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon) {
    return SizedBox(
      width: 160,
      child: NileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: NileColors.primary, size: 22),
            const SizedBox(height: 8),
            Text(value, style: NileTypography.headlineMedium),
            Text(label, style: NileTypography.caption),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, String label, String route, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: NileColors.primary),
      title: Text(label, style: NileTypography.titleSmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(route),
    );
  }
}
