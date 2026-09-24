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
  String _search = '';

  bool get _isTestimonials => widget.table == 'testimonials';

  String get _orderColumn {
    switch (widget.table) {
      case 'pages':
        return 'updated_at';
      case 'faqs':
      case 'videos':
        return 'sort_order';
      default:
        return 'created_at';
    }
  }

  bool get _orderAscending =>
      widget.table == 'faqs' || widget.table == 'videos';

  List<_Field> get _fields {
    switch (widget.table) {
      case 'pages':
        return const [
          _Field('slug', 'URL slug', help: 'Example: about-us'),
          _Field('title', 'Page title'),
          _Field('body', 'Page content', multiline: true),
          _Field('is_published', 'Published', boolean: true),
        ];
      case 'faqs':
        return const [
          _Field('question', 'Question'),
          _Field('answer', 'Answer', multiline: true),
          _Field('sort_order', 'Display order', numeric: true),
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
          _Field('sort_order', 'Display order', numeric: true),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Connect Supabase to manage ' + widget.title + '.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await SupabaseService.client
          .from(widget.table)
          .select()
          .order(_orderColumn, ascending: _orderAscending);

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

  List<Map<String, dynamic>> get _filteredRows {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((row) {
      return row.values.any((value) =>
          value != null && value.toString().toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};

    for (final field in _fields) {
      final value = existing?[field.key];
      if (field.boolean) {
        boolValues[field.key] = value == true;
      } else {
        controllers[field.key] =
            TextEditingController(text: value?.toString() ?? '');
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? 'Add ' + widget.title
              : 'Edit ' + widget.title),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                children: _fields.map((field) {
                  if (field.boolean) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(field.label),
                      value: boolValues[field.key] ?? false,
                      onChanged: (v) =>
                          setDialogState(() => boolValues[field.key] = v),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: controllers[field.key],
                      maxLines: field.multiline ? 7 : 1,
                      keyboardType: field.numeric
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: field.label,
                        helperText: field.help,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      _disposeControllers(controllers);
      return;
    }

    final payload = <String, dynamic>{};
    for (final field in _fields) {
      if (field.boolean) {
        payload[field.key] = boolValues[field.key] ?? false;
      } else {
        final value = controllers[field.key]!.text.trim();
        if (field.numeric) {
          payload[field.key] = int.tryParse(value) ?? 0;
        } else {
          payload[field.key] = value.isEmpty ? null : value;
        }
      }
    }

    if (widget.table == 'pages' &&
        (payload['slug'] == null || payload['slug'].toString().isEmpty)) {
      _showError('A URL slug is required for a page.');
      _disposeControllers(controllers);
      return;
    }

    if (_isTestimonials &&
        payload['is_published'] == true &&
        payload['consent_given'] != true) {
      _showError(
        'A testimonial cannot be published until consent is recorded.',
      );
      _disposeControllers(controllers);
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
      _showError('Save failed: ' + e.toString());
    } finally {
      _disposeControllers(controllers);
    }
  }

  void _disposeControllers(Map<String, TextEditingController> controllers) {
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: NileColors.error),
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final label =
        row[widget.titleField]?.toString() ?? row['id'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete “' + label + '” from ' + widget.title + '?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: NileColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await SupabaseService.client
          .from(widget.table)
          .delete()
          .eq('id', row['id']);
      await _load();
    } catch (e) {
      _showError('Delete failed: ' + e.toString());
    }
  }

  String _statusText(Map<String, dynamic> row) {
    if (row.containsKey('is_published')) {
      return row['is_published'] == true ? 'Published' : 'Draft';
    }
    if (row.containsKey('is_active')) {
      return row['is_active'] == true ? 'Active' : 'Inactive';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: NileColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load ' + widget.title + '.',
                          style: NileTypography.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _search = value),
                        decoration: InputDecoration(
                          hintText:
                              'Search ' + widget.title.toLowerCase() + '…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () =>
                                      setState(() => _search = ''),
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rows.length.toString() +
                              ' of ' +
                              _rows.length.toString() +
                              ' ' +
                              widget.title.toLowerCase(),
                          style: NileTypography.bodySmall,
                        ),
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? Center(
                              child: Text(
                                _rows.isEmpty
                                    ? 'No ' +
                                        widget.title.toLowerCase() +
                                        ' yet.'
                                    : 'No ' +
                                        widget.title.toLowerCase() +
                                        ' match your search.',
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final row = rows[i];
                                final status = _statusText(row);
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      row[widget.titleField]?.toString() ??
                                          row['id'].toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget.subtitleField != null)
                                          Text(
                                            row[widget.subtitleField]
                                                    ?.toString() ??
                                                '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (status.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: row['is_published'] ==
                                                            true ||
                                                        row['is_active'] ==
                                                            true
                                                    ? NileColors.success
                                                    : NileColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'edit') _edit(row);
                                        if (action == 'delete') _delete(row);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete')),
                                      ],
                                    ),
                                    onTap: () => _edit(row),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _Field {
  const _Field(
    this.key,
    this.label, {
    this.multiline = false,
    this.boolean = false,
    this.numeric = false,
    this.help,
  });

  final String key;
  final String label;
  final bool multiline;
  final bool boolean;
  final bool numeric;
  final String? help;
}
