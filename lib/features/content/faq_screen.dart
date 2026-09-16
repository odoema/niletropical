import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
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
        _error = 'Connect Supabase to load FAQs.';
      });
      return;
    }
    try {
      final rows = await SupabaseService.fetchPublishedFaqs();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
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
      appBar: const NileAppBar(title: 'FAQs'),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(title: 'FAQs', message: _error)
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    return ExpansionTile(
                      title: Text(r['question']?.toString() ?? ''),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(NileSpacing.md),
                          child: Text(r['answer']?.toString() ?? ''),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
