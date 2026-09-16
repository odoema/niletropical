import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/constants/app_constants.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          NileCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: NileColors.primaryContainer,
                  child: Icon(Icons.person, color: NileColors.primary, size: 32),
                ),
                const SizedBox(width: NileSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest', style: NileTypography.titleLarge),
                      Text('Sign in to sync orders & addresses', style: NileTypography.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NileSpacing.md),
          _tile(context, Icons.receipt_long_outlined, 'My orders', '/account/orders'),
          _tile(context, Icons.location_on_outlined, 'Addresses', '/account/addresses'),
          _tile(context, Icons.local_shipping_outlined, 'Track order', '/track'),
          _tile(context, Icons.help_outline, 'FAQs', '/faq'),
          _tile(context, Icons.article_outlined, 'About', '/pages/about'),
          const Divider(height: 32),
          _tile(context, Icons.admin_panel_settings_outlined, 'Admin console', '/admin'),
          _tile(context, Icons.delivery_dining_outlined, 'Courier app', '/courier'),
          _tile(context, Icons.palette_outlined, 'Design system', '/design-system'),
          const SizedBox(height: NileSpacing.xl),
          Text(AppConstants.copyright, style: NileTypography.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: NileColors.primary),
      title: Text(label, style: NileTypography.titleSmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
      shape: RoundedRectangleBorder(borderRadius: NileRadius.borderSm),
    );
  }
}
