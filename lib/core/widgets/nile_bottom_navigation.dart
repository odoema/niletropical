/// Customer bottom navigation
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileBottomNavItem {
  const NileBottomNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class NileBottomNavigation extends StatelessWidget {
  const NileBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NileBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: items
          .map(
            (i) => NavigationDestination(
              icon: Icon(i.icon),
              selectedIcon: Icon(i.selectedIcon ?? i.icon),
              label: i.label,
            ),
          )
          .toList(),
    );
  }
}
