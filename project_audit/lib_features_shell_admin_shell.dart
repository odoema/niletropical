/// Admin shell with side navigation
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import 'responsive_scaffold.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _destinations = [
    NileSideNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, route: '/admin'),
    NileSideNavItem(label: 'Orders', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, route: '/admin/orders'),
    NileSideNavItem(label: 'Products', icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, route: '/admin/products'),
    NileSideNavItem(label: 'Inventory', icon: Icons.warehouse_outlined, selectedIcon: Icons.warehouse, route: '/admin/inventory'),
    NileSideNavItem(label: 'Delivery', icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping, route: '/admin/delivery'),
    NileSideNavItem(label: 'Customers', icon: Icons.people_outline, selectedIcon: Icons.people, route: '/admin/customers'),
    NileSideNavItem(label: 'COD', icon: Icons.payments_outlined, selectedIcon: Icons.payments, route: '/admin/finance/cod'),
    NileSideNavItem(label: 'CMS', icon: Icons.article_outlined, selectedIcon: Icons.article, route: '/admin/cms'),
    NileSideNavItem(label: 'Reports', icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, route: '/admin/reports'),
  ];

  int get _index {
    if (location.startsWith('/admin/orders')) return 1;
    if (location.startsWith('/admin/products')) return 2;
    if (location.startsWith('/admin/inventory')) return 3;
    if (location.startsWith('/admin/delivery')) return 4;
    if (location.startsWith('/admin/customers')) return 5;
    if (location.startsWith('/admin/finance')) return 6;
    if (location.startsWith('/admin/cms')) return 7;
    if (location.startsWith('/admin/reports')) return 8;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedIndex: _index,
      destinations: _destinations,
      onDestinationSelected: (i) {
        final route = _destinations[i].route;
        if (route != null) context.go(route);
      },
      sideHeader: Padding(
        padding: const EdgeInsets.all(NileSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nile Admin', style: NileTypography.titleLarge.copyWith(color: NileColors.primary)),
            Text('Operations console', style: NileTypography.caption),
          ],
        ),
      ),
      sideFooter: Padding(
        padding: const EdgeInsets.all(NileSpacing.md),
        child: TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('Customer site'),
        ),
      ),
      body: child,
    );
  }
}
