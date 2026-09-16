import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';

class CmsCollectionScreen extends StatefulWidget {
  const CmsCollectionScreen({
    super.key,
    required this.title,
    required this.table,
    required this.titleField,
    this.subtitleField,
  });

  final String title;
  final String table;
  final String titleField;
  final String? subtitleField;

  @override
  State<CmsCollectionScreen> createState() => _CmsCollectionScreenState();
}

class _CmsCollectionScreenState extends State<CmsCollectionScreen> {
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
        _error = 'Connect Supabase to manage ${widget.title}.';
      });
      return;
    }
    try {
      final rows = await SupabaseService.client.from(widget.table).select();
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
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

  Future<void> _upsert([Map<String, dynamic>? existing]) async {
    final title = TextEditingController(text: existing?[widget.titleField]?.toString() ?? '');
    final sub = TextEditingController(
      text: widget.subtitleField == null ? '' : existing?[widget.subtitleField]?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add ${widget.title}' : 'Edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: InputDecoration(labelText: widget.titleField)),
            if (widget.subtitleField != null)
              TextField(controller: sub, decoration: InputDecoration(labelText: widget.subtitleField)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final payload = <String, dynamic>{widget.titleField: title.text.trim()};
    if (widget.subtitleField != null) {
      payload[widget.subtitleField!] = sub.text.trim();
    }
    if (existing == null) {
      await SupabaseService.client.from(widget.table).insert(payload);
    } else {
      await SupabaseService.client.from(widget.table).update(payload).eq('id', existing['id']);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NileAppBar(title: widget.title),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _upsert(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(title: widget.title, message: _error)
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    return ListTile(
                      title: Text(r[widget.titleField]?.toString() ?? r['id'].toString()),
                      subtitle: widget.subtitleField == null
                          ? null
                          : Text(r[widget.subtitleField]?.toString() ?? ''),
                      onTap: () => _upsert(r),
                    );
                  },
                ),
    );
  }
}
