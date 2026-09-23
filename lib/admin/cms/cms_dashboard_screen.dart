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
          const SizedBox(height: 8),
          Text(
            'Manage storefront content and media without touching code.',
            style: NileTypography.bodyMedium,
          ),
          const SizedBox(height: NileSpacing.md),
          NileCard(
            margin: const EdgeInsets.only(bottom: NileSpacing.md),
            onTap: () => context.go('/admin/cms/media'),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: NileColors.primaryContainer,
                    borderRadius: NileRadius.borderMd,
                  ),
                  child: const Icon(Icons.perm_media_outlined, color: NileColors.primary, size: 28),
                ),
                const SizedBox(width: NileSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Media Library', style: NileTypography.titleMedium),
                      Text(
                        'Upload website images, banners and CMS media. Preview, copy URLs and delete files.',
                        style: NileTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: NileColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: NileSpacing.md),
          _section(context, Icons.web_outlined, 'Website Slots', 'Choose which uploaded images power the public website', '/admin/cms/website-slots'),
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
