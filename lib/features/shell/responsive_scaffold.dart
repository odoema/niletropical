/// Responsive scaffold: bottom nav on mobile, side rail on wide screens
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/notification_inbox_service.dart';

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.appBar,
    this.floatingActionButton,
    this.sideHeader,
    this.sideFooter,
    this.breakpoint = 800,
  });

  final Widget body;
  final List<NileSideNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? sideHeader;
  final Widget? sideFooter;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: NileSideNavigation(
                    items: destinations,
                    selectedIndex: selectedIndex,
                    onSelect: onDestinationSelected,
                    header: sideHeader,
                    footer: sideFooter,
                  ),
                ),
                const VerticalDivider(width: 1, color: NileColors.border),
                Expanded(
                  child: Scaffold(
                    appBar: appBar,
                    body: Column(
                      children: [
                        _WebsiteBanner(),
                        Expanded(child: body),
                      ],
                    ),
                    floatingActionButton: floatingActionButton,
                  ),
                ),
              ],
            ),
          );
        }
        // Mobile: bottom nav
        return Scaffold(
          appBar: appBar,
          body: Column(
            children: [
              _WebsiteBanner(),
              Expanded(child: body),
            ],
          ),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: destinations.length <= 5
              ? NavigationBar(
                  selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations
                      .map(
                        (d) => NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon ?? d.icon),
                          label: d.label,
                        ),
                      )
                      .toList(),
                )
              : _MobileAdminNavigation(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: onDestinationSelected,
                ),
        );
      },
    );
  }
}


class _WebsiteBanner extends StatelessWidget {
  const _WebsiteBanner();

  static final Uri _website = Uri.parse('https://niletropicaluganda.com/');

  Future<void> _openWebsite(BuildContext context) async {
    final opened = await launchUrl(
      _website,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Nile Tropical website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NileColors.primary,
      child: InkWell(
        onTap: () => _openWebsite(context),
        child: SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.public, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'GO TO WEBSITE',
                    style: NileTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                ),
                const _NotificationBell(),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: NileColors.primaryDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'OPEN',
                        style: NileTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _MobileAdminNavigation extends StatelessWidget {
  const _MobileAdminNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NileSideNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = destinations.take(4).toList();
    final moreSelected = selectedIndex >= 4;
    return NavigationBar(
      selectedIndex: moreSelected ? 4 : selectedIndex,
      onDestinationSelected: (index) {
        if (index < 4) {
          onSelected(index);
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Admin menu', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('All administration modules'),
                ),
                ...List.generate(destinations.length, (i) {
                  final item = destinations[i];
                  return ListTile(
                    leading: Icon(
                      i == selectedIndex
                          ? (item.selectedIcon ?? item.icon)
                          : item.icon,
                      color: i == selectedIndex ? NileColors.primary : null,
                    ),
                    title: Text(item.label),
                    selected: i == selectedIndex,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSelected(i);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
      destinations: [
        ...visible.map(
          (d) => NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon ?? d.icon),
            label: d.label,
          ),
        ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();
  @override State<_NotificationBell> createState() => _NotificationBellState();
}
class _NotificationBellState extends State<_NotificationBell> {
  Future<int> _count() async {
    if (AuthService.user == null) return 0;
    final rows = await NotificationInboxService.fetch(limit: 20);
    return rows.length;
  }
  @override
  Widget build(BuildContext context) {
    if (AuthService.user == null) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: _count(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 23),
              if (count > 0)
                Positioned(
                  right: -5, top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      count > 9 ? '9+' : count.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
