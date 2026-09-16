/// Admin / desktop side navigation rail or drawer items
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileSideNavItem {
  const NileSideNavItem({
    required this.label,
    required this.icon,
    this.route,
    this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? route;
}

class NileSideNavigation extends StatelessWidget {
  const NileSideNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.header,
    this.footer,
  });

  final List<NileSideNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NileColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: NileSpacing.sm),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return ListTile(
                    leading: Icon(
                      selected ? (item.selectedIcon ?? item.icon) : item.icon,
                      color: selected ? NileColors.primary : NileColors.textSecondary,
                    ),
                    title: Text(
                      item.label,
                      style: NileTypography.labelLarge.copyWith(
                        color: selected ? NileColors.primary : NileColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor: NileColors.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: NileRadius.borderSm),
                    onTap: () => onSelect(index),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  );
                },
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}
