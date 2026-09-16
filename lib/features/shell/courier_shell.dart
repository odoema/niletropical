/// Courier shell — focused on assigned shipments + POD
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import 'responsive_scaffold.dart';

class CourierShell extends StatelessWidget {
  const CourierShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _destinations = [
    NileSideNavItem(label: 'My runs', icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping, route: '/courier'),
    NileSideNavItem(label: 'History', icon: Icons.history, selectedIcon: Icons.history, route: '/courier/history'),
  ];

  int get _index => location.startsWith('/courier/history') ? 1 : 0;

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
        child: Text('Courier', style: NileTypography.titleLarge.copyWith(color: NileColors.primary)),
      ),
      body: child,
    );
  }
}
