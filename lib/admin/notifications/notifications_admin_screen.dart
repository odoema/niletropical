import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class NotificationsAdminScreen extends StatefulWidget {
  const NotificationsAdminScreen({super.key});
  @override
  State<NotificationsAdminScreen> createState() => _NotificationsAdminScreenState();
}

class _NotificationsAdminScreenState extends State<NotificationsAdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() { _loading = false; _error = 'Supabase is not configured.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        SupabaseService.client.from('notification_templates').select().order('event_key'),
        SupabaseService.client.from('notification_logs').select('*, notifications(recipient, channel, event_key, order_id)').order('created_at', ascending: false).limit(200),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = List<Map<String, dynamic>>.from(results[0]);
        _logs = List<Map<String, dynamic>>.from(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _editTemplate([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['event_key']?.toString() ?? '');
    final channel = TextEditingController(text: existing?['channel']?.toString() ?? 'push');
    final body = TextEditingController(text: existing?['template_body']?.toString() ?? '');
    bool active = existing?['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'New notification template' : 'Edit notification template'),
        content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name / key')),
          TextField(controller: channel, decoration: const InputDecoration(labelText: 'Channel (push, SMS, email, WhatsApp)')),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
          TextField(controller: body, maxLines: 7, decoration: const InputDecoration(labelText: 'Message body')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => setDialogState(() => active = v)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      )),
    );
    if (ok != true) { for (final c in [name, channel, body]) c.dispose(); return; }
    try {
      final payload = {'event_key': name.text.trim(), 'channel': channel.text.trim(), 'template_body': body.text.trim(), 'is_active': active};
      if (existing == null) {
        await SupabaseService.client.from('notification_templates').insert(payload);
      } else {
        await SupabaseService.client.from('notification_templates').update(payload).eq('id', existing['id']);
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ' + e.toString()), backgroundColor: NileColors.error));
    } finally { for (final c in [name, channel, body]) c.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [FilledButton.icon(onPressed: () => _editTemplate(), icon: const Icon(Icons.add), label: const Text('Template')), const SizedBox(width: 8), IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Templates'), Tab(text: 'Delivery Log')]),
      ),
      body: _loading ? const NileLoadingState() : _error != null ? NileErrorState(message: _error!, onRetry: _load) :
        TabBarView(controller: _tabs, children: [_templatesView(), _logsView()]),
    );
  }

  Widget _templatesView() => _templates.isEmpty ? const Center(child: Text('No notification templates configured.')) :
    ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: _templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _templates[i];
        return Card(child: ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text((r['event_key'] ?? 'Template').toString()),
          subtitle: Text((r['channel'] ?? '—').toString() + ' • ' + (r['is_active'] == false ? 'Inactive' : 'Active') + '\n' + (r['template_body'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editTemplate(r)),
        ));
      },
    );

  Widget _logsView() => _logs.isEmpty ? const Center(child: Text('No notification delivery logs.')) :
    ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _logs[i];
        final n = Map<String, dynamic>.from(r['notifications'] as Map? ?? {});
        final status = r['status']?.toString() ?? 'unknown';
        return Card(child: ListTile(
          leading: Icon(status == 'sent' || status == 'delivered' ? Icons.check_circle_outline : Icons.error_outline),
          title: Text((n['channel'] ?? 'notification').toString() + ' • ' + status),
          subtitle: Text((r['recipient'] ?? r['recipient_phone'] ?? r['recipient_email'] ?? r['user_id'] ?? '').toString() + '\n' + (r['created_at'] ?? '').toString(), maxLines: 2),
        ));
      },
    );
}
