/// Responsive scaffold: bottom nav on mobile, side rail on wide screens
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';

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
          bottomNavigationBar: NavigationBar(
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
                    'NILE TROPICAL WEBSITE',
                    style: NileTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
