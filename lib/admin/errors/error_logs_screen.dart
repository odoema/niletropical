import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/errors/error_reporter.dart';
import '../../shared/services/supabase_service.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});
  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  bool _loading = true;
  String? _error;
  String _severity = 'all';
  bool _unresolvedOnly = false;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Error logging is not configured.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await SupabaseService.client
          .from('app_error_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(300);

      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        stackTrace: stack,
        source: 'admin_error_logs',
        action: 'load_error_logs',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorReporter.friendlyMessage(e);
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    return _rows.where((row) {
      final severity = row['severity']?.toString().toLowerCase() ?? 'error';
      final matchesSeverity = _severity == 'all' || severity == _severity;
      final matchesResolved = !_unresolvedOnly || row['resolved_at'] == null;
      return matchesSeverity && matchesResolved;
    }).toList();
  }

  Future<void> _resolve(Map<String, dynamic> row) async {
    final noteController = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve error'),
        content: TextField(
          controller: noteController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Resolution note (optional)',
            hintText: 'What was checked or fixed?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, noteController.text.trim()),
            child: const Text('Mark resolved'),
          ),
        ],
      ),
    );
    noteController.dispose();

    if (note == null) return;

    try {
      await SupabaseService.client
          .from('app_error_logs')
          .update({
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
            'resolved_by': SupabaseService.client.auth.currentUser?.id,
            'resolution_note': note.isEmpty ? null : note,
          })
          .eq('id', row['id']);

      await _load();
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        stackTrace: stack,
        source: 'admin_error_logs',
        action: 'resolve_error',
        context: {'error_log_id': row['id']},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorReporter.friendlyMessage(e)),
            backgroundColor: NileColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final unresolved = _rows.where((r) => r['resolved_at'] == null).length;
    final fatal = _rows.where((r) => r['severity'] == 'fatal').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh error logs',
          ),
        ],
      ),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileErrorState(
                  title: 'Error logs unavailable',
                  message: _error,
                  onRetry: _load,
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _summary('Total', '${_rows.length}', Icons.error_outline),
                          _summary('Unresolved', '$unresolved', Icons.warning_amber_outlined),
                          _summary('Fatal', '$fatal', Icons.priority_high),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in ['all', 'fatal', 'error', 'warning', 'info'])
                            ChoiceChip(
                              label: Text(value == 'all' ? 'All' : value[0].toUpperCase() + value.substring(1)),
                              selected: _severity == value,
                              onSelected: (_) => setState(() => _severity = value),
                            ),
                          FilterChip(
                            label: const Text('Unresolved only'),
                            selected: _unresolvedOnly,
                            onSelected: (value) => setState(() => _unresolvedOnly = value),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('No errors match the selected filters.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, index) => _ErrorLogCard(
                                row: visible[index],
                                onResolve: visible[index]['resolved_at'] == null
                                    ? () => _resolve(visible[index])
                                    : null,
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _summary(String label, String value, IconData icon) {
    return SizedBox(
      width: 150,
      child: NileCard(
        child: Row(
          children: [
            Icon(icon, color: NileColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: NileTypography.titleLarge),
                  Text(label, style: NileTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorLogCard extends StatelessWidget {
  const _ErrorLogCard({required this.row, required this.onResolve});
  final Map<String, dynamic> row;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final severity = row['severity']?.toString() ?? 'error';
    final resolved = row['resolved_at'] != null;
    final message = row['message']?.toString() ?? 'Application error';
    final source = row['source']?.toString() ?? 'flutter';
    final route = row['route']?.toString();
    final action = row['action']?.toString();
    final technical = row['technical_message']?.toString();
    final stack = row['stack_trace']?.toString();
    final created = row['created_at']?.toString() ?? '';
    final code = row['error_code']?.toString();

    return NileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SeverityBadge(severity: severity),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: NileTypography.titleSmall)),
              if (resolved)
                const Chip(
                  avatar: Icon(Icons.check_circle_outline, size: 16),
                  label: Text('Resolved'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              source,
              if (code != null && code.isNotEmpty) 'code: $code',
              if (action != null && action.isNotEmpty) 'action: $action',
              if (route != null && route.isNotEmpty) 'route: $route',
              created,
            ].join('  •  '),
            style: NileTypography.caption,
          ),
          if (technical != null && technical.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Technical details'),
              children: [
                SelectableText(technical, style: NileTypography.bodySmall),
                if (stack != null && stack.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(stack, style: NileTypography.caption),
                ],
              ],
            ),
          ],
          if (!resolved)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark resolved'),
              ),
            )
          else if (row['resolution_note'] != null)
            Text(
              'Resolution: ${row['resolution_note']}',
              style: NileTypography.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});
  final String severity;

  @override
  Widget build(BuildContext context) {
    final icon = switch (severity) {
      'fatal' => Icons.priority_high,
      'warning' => Icons.warning_amber_outlined,
      'info' => Icons.info_outline,
      _ => Icons.error_outline,
    };

    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(severity.toUpperCase()),
      visualDensity: VisualDensity.compact,
    );
  }
}
