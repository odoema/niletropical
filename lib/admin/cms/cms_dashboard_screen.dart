import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';

class CmsDashboardScreen extends StatelessWidget {
  const CmsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'CMS'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          Text('Content management', style: NileTypography.headlineSmall),
          const SizedBox(height: NileSpacing.md),
          _section(context, Icons.image_outlined, 'Banners', 'Home & promo banners', '/admin/cms/banners'),
          _section(context, Icons.article_outlined, 'Pages', 'Static pages', '/admin/cms/pages'),
          _section(context, Icons.help_outline, 'FAQs', 'Customer FAQ entries', '/admin/cms/faqs'),
          _section(context, Icons.format_quote_outlined, 'Testimonials', 'Customer quotes', '/admin/cms/testimonials'),
          _section(context, Icons.videocam_outlined, 'Videos', 'Product & brand videos', '/admin/cms/videos'),
          _section(context, Icons.local_offer_outlined, 'Promotions', 'Coupons & campaigns', '/admin/cms/promotions'),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, IconData icon, String title, String subtitle, String route) {
    return NileCard(
      margin: const EdgeInsets.only(bottom: NileSpacing.sm),
      onTap: () => context.go(route),
      child: Row(
        children: [
          Icon(icon, color: NileColors.primary, size: 28),
          const SizedBox(width: NileSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NileTypography.titleMedium),
                Text(subtitle, style: NileTypography.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: NileColors.textTertiary),
        ],
      ),
    );
  }
}
