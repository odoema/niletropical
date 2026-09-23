import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
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

  bool get _isTestimonials => widget.table == 'testimonials';

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
      final rows = await SupabaseService.client
          .from(widget.table)
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<_Field> get _fields {
    switch (widget.table) {
      case 'pages':
        return const [
          _Field('slug', 'Slug', multiline: false),
          _Field('title', 'Title'),
          _Field('body', 'Body', multiline: true),
          _Field('is_published', 'Published', boolean: true),
        ];
      case 'faqs':
        return const [
          _Field('question', 'Question'),
          _Field('answer', 'Answer', multiline: true),
          _Field('sort_order', 'Display order'),
          _Field('is_active', 'Active', boolean: true),
        ];
      case 'testimonials':
        return const [
          _Field('customer_name', 'Customer name'),
          _Field('location', 'Location'),
          _Field('testimonial', 'Testimonial', multiline: true),
          _Field('photo_storage_path', 'Photo storage path'),
          _Field('consent_given', 'Consent given', boolean: true),
          _Field('is_published', 'Published', boolean: true),
          _Field('is_featured', 'Featured', boolean: true),
        ];
      case 'videos':
        return const [
          _Field('title', 'Title'),
          _Field('description', 'Description', multiline: true),
          _Field('storage_path', 'Video storage path'),
          _Field('thumbnail_path', 'Thumbnail path'),
          _Field('category', 'Category'),
          _Field('sort_order', 'Display order'),
          _Field('is_published', 'Published', boolean: true),
          _Field('is_featured', 'Featured', boolean: true),
        ];
      case 'promotions':
        return const [
          _Field('name', 'Promotion name'),
          _Field('description', 'Description', multiline: true),
          _Field('starts_at', 'Starts at (ISO timestamp)'),
          _Field('ends_at', 'Ends at (ISO timestamp)'),
          _Field('is_active', 'Active', boolean: true),
        ];
      default:
        return [
          _Field(widget.titleField, widget.titleField),
          if (widget.subtitleField != null)
            _Field(widget.subtitleField!, widget.subtitleField!),
        ];
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};

    for (final field in _fields) {
      final value = existing?[field.key];
      if (field.boolean) {
        boolValues[field.key] = value == true;
      } else {
        controllers[field.key] = TextEditingController(text: value?.toString() ?? '');
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add ${widget.title}' : 'Edit ${widget.title}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: _fields.map((field) {
                  if (field.boolean) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(field.label),
                      value: boolValues[field.key] ?? false,
                      onChanged: (v) => setDialogState(() => boolValues[field.key] = v),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[field.key],
                      maxLines: field.multiline ? 5 : 1,
                      decoration: InputDecoration(
                        labelText: field.label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) {
      for (final c in controllers.values) c.dispose();
      return;
    }

    final payload = <String, dynamic>{};
    for (final field in _fields) {
      if (field.boolean) {
        payload[field.key] = boolValues[field.key] ?? false;
      } else {
        final value = controllers[field.key]!.text.trim();
        if (field.key == 'sort_order') {
          payload[field.key] = int.tryParse(value) ?? 0;
        } else {
          payload[field.key] = value.isEmpty ? null : value;
        }
      }
    }

    // Testimonials are deliberately consent-gated at both the UI and DB
    // layers; publishing without consent should never be possible.
    if (_isTestimonials &&
        payload['is_published'] == true &&
        payload['consent_given'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A testimonial cannot be published until consent is recorded.'),
            backgroundColor: NileColors.error,
          ),
        );
      }
      for (final c in controllers.values) c.dispose();
      return;
    }

    try {
      if (existing == null) {
        await SupabaseService.client.from(widget.table).insert(payload);
      } else {
        await SupabaseService.client
            .from(widget.table)
            .update(payload)
            .eq('id', existing['id']);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: NileColors.error),
        );
      }
    } finally {
      for (final c in controllers.values) c.dispose();
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final label = row[widget.titleField]?.toString() ?? row['id'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete “$label” from ${widget.title}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: NileColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client.from(widget.table).delete().eq('id', row['id']);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: NileColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(title: widget.title, message: _error)
              : _rows.isEmpty
                  ? Center(child: Text('No ${widget.title.toLowerCase()} yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final row = _rows[i];
                        return Card(
                          child: ListTile(
                            title: Text(
                              row[widget.titleField]?.toString() ?? row['id'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: widget.subtitleField == null
                                ? null
                                : Text(
                                    row[widget.subtitleField]?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'edit') _edit(row);
                                if (action == 'delete') _delete(row);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                            onTap: () => _edit(row),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _Field {
  const _Field(this.key, this.label, {this.multiline = false, this.boolean = false});
  final String key;
  final String label;
  final bool multiline;
  final bool boolean;
}
