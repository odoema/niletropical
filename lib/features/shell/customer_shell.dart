/// Customer shell with bottom / side navigation
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import 'responsive_scaffold.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _destinations = [
    NileSideNavItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home, route: '/'),
    NileSideNavItem(label: 'Shop', icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, route: '/shop'),
    NileSideNavItem(label: 'Cart', icon: Icons.shopping_cart_outlined, selectedIcon: Icons.shopping_cart, route: '/cart'),
    NileSideNavItem(label: 'Track', icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping, route: '/track'),
    NileSideNavItem(label: 'Account', icon: Icons.person_outline, selectedIcon: Icons.person, route: '/account'),
  ];

  int get _index {
    if (location.startsWith('/shop') || location.startsWith('/product')) return 1;
    if (location.startsWith('/cart') || location.startsWith('/checkout')) return 2;
    if (location.startsWith('/track')) return 3;
    if (location.startsWith('/account')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      selectedIndex: _index,
      destinations: _destinations,
      onDestinationSelected: (i) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final route = _destinations[i].route;
        if (route != null) context.go(route);
      },
      sideHeader: SizedBox(
        // Keep the header at its existing height so enlarging the logo
        // does not push the side-menu items downward.
        height: 68,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ClipOval(
                child: Image(
                  image: AssetImage('assets/images/logo.png'),
                  width: 47,
                  height: 47,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text('Nile Tropical', style: NileTypography.titleMedium.copyWith(color: NileColors.primary)),
            ],
          ),
        ),
      ),
      body: child,
    );
  }
}
