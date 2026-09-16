import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';

class CmsPageScreen extends StatefulWidget {
  const CmsPageScreen({super.key, required this.slug});
  final String slug;

  @override
  State<CmsPageScreen> createState() => _CmsPageScreenState();
}

class _CmsPageScreenState extends State<CmsPageScreen> {
  bool _loading = true;
  Map<String, dynamic>? _page;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Connect Supabase to load this page.';
      });
      return;
    }
    try {
      final page = await SupabaseService.fetchPage(widget.slug);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
        if (page == null) _error = 'Page not found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NileAppBar(title: _page?['title']?.toString() ?? widget.slug),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(title: widget.slug, message: _error)
              : ListView(
                  padding: const EdgeInsets.all(NileSpacing.md),
                  children: [
                    Text(_page!['title']?.toString() ?? '', style: NileTypography.headlineSmall),
                    const SizedBox(height: NileSpacing.md),
                    Text(_page!['body']?.toString() ?? '', style: NileTypography.bodyLarge),
                  ],
                ),
    );
  }
}
