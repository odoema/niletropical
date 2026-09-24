import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class CmsDashboardScreen extends StatefulWidget {
  const CmsDashboardScreen({super.key});

  @override
  State<CmsDashboardScreen> createState() => _CmsDashboardScreenState();
}

class _CmsDashboardScreenState extends State<CmsDashboardScreen> {
  bool _loading = true;
  String? _error;
  final Map<String, int> _counts = {};

  static const _collections = <_CmsSection>[
    _CmsSection('Pages', 'pages', Icons.article_outlined, '/admin/cms/pages'),
    _CmsSection('FAQs', 'faqs', Icons.help_outline, '/admin/cms/faqs'),
    _CmsSection('Testimonials', 'testimonials', Icons.format_quote_outlined, '/admin/cms/testimonials'),
    _CmsSection('Videos', 'videos', Icons.videocam_outlined, '/admin/cms/videos'),
    _CmsSection('Promotions', 'promotions', Icons.local_offer_outlined, '/admin/cms/promotions'),
    _CmsSection('Banners', 'banners', Icons.image_outlined, '/admin/cms/banners'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Connect Supabase to load CMS status.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait(
        _collections.map(
          (section) => SupabaseService.client.from(section.table).select('id'),
        ),
      );

      if (!mounted) return;
      for (var i = 0; i < _collections.length; i++) {
        _counts[_collections[i].table] = (results[i] as List).length;
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int get _totalContent =>
      _counts.values.fold(0, (sum, count) => sum + count);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NileAppBar(
        title: 'CMS',
        actions: [
          IconButton(
            tooltip: 'Refresh CMS',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(NileSpacing.md),
          children: [
            Text('Content management', style: NileTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Control what customers see across the Nile Tropical website and app.',
              style: NileTypography.bodyMedium,
            ),
            const SizedBox(height: NileSpacing.md),
            if (_error != null)
              NileCard(
                margin: const EdgeInsets.only(bottom: NileSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: NileColors.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text('CMS status could not be loaded: ' + _error!)),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    'Content items',
                    _totalContent.toString(),
                    Icons.dashboard_customize_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricCard(
                    'Managed areas',
                    _collections.length.toString(),
                    Icons.tune_outlined,
                  ),
                ),
              ],
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
                    child: const Icon(
                      Icons.perm_media_outlined,
                      color: NileColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: NileSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Media Library', style: NileTypography.titleMedium),
                        Text(
                          'Upload, preview and safely reuse website and campaign media.',
                          style: NileTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: NileColors.textTertiary),
                ],
              ),
            ),
            Text('Content areas', style: NileTypography.titleLarge),
            const SizedBox(height: 8),
            ..._collections.map(
              (section) => _section(
                context,
                section,
                _counts[section.table] ?? 0,
              ),
            ),
            const SizedBox(height: 8),
            Text('Website presentation', style: NileTypography.titleLarge),
            const SizedBox(height: 8),
            _section(
              context,
              const _CmsSection(
                'Website Slots',
                'website_media_slots',
                Icons.web_outlined,
                '/admin/cms/website-slots',
              ),
              null,
              subtitle: 'Choose which approved media powers key website locations.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return NileCard(
      child: Row(
        children: [
          Icon(icon, color: NileColors.primary, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: NileTypography.headlineSmall),
              Text(label, style: NileTypography.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    _CmsSection section,
    int? count, {
    String? subtitle,
  }) {
    return NileCard(
      margin: const EdgeInsets.only(bottom: NileSpacing.sm),
      onTap: () => context.go(section.route),
      child: Row(
        children: [
          Icon(section.icon, color: NileColors.primary, size: 28),
          const SizedBox(width: NileSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        section.title,
                        style: NileTypography.titleMedium,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NileColors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          count.toString(),
                          style: NileTypography.labelSmall.copyWith(
                            color: NileColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle ?? _subtitleFor(section.title),
                  style: NileTypography.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: NileColors.textTertiary),
        ],
      ),
    );
  }

  String _subtitleFor(String title) {
    switch (title) {
      case 'Pages':
        return 'Manage publishable company pages.';
      case 'FAQs':
        return 'Manage customer questions and answers.';
      case 'Testimonials':
        return 'Manage approved customer stories and quotes.';
      case 'Videos':
        return 'Manage brand and product video content.';
      case 'Promotions':
        return 'Manage time-bound promotional content.';
      case 'Banners':
        return 'Manage homepage promotional banners.';
      default:
        return 'Manage customer-facing content.';
    }
  }
}

class _CmsSection {
  const _CmsSection(this.title, this.table, this.icon, this.route);

  final String title;
  final String table;
  final IconData icon;
  final String route;
}
