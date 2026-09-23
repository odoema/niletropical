import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() { _loading = false; _error = 'Supabase is not configured.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      List<Map<String, dynamic>> rows;
      try {
        final r = await SupabaseService.client.schema('nile_admin').from('admin_activity_log').select().order('created_at', ascending: false).limit(300);
        rows = List<Map<String, dynamic>>.from(r);
      } catch (_) {
        final r = await SupabaseService.client.from('audit_logs').select().order('created_at', ascending: false).limit(300);
        rows = List<Map<String, dynamic>>.from(r);
      }
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const NileLoadingState() : _error != null ? NileErrorState(message: _error!, onRetry: _load) :
        _rows.isEmpty ? const Center(child: Text('No staff activity recorded yet.')) :
        ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: _rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = _rows[i];
            final action = r['action'] ?? r['event'] ?? r['operation'] ?? 'Activity';
            final actor = r['actor_email'] ?? r['email'] ?? r['user_id'] ?? 'Unknown user';
            final target = r['entity_type'] != null ? (r['entity_type'].toString() + ': ' + (r['entity_id'] ?? '').toString()) : (r['table_name'] ?? '');
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.history)),
              title: Text(action.toString()),
              subtitle: Text(actor.toString() + '\n' + target.toString() + '\n' + (r['created_at'] ?? '').toString(), maxLines: 3),
              isThreeLine: true,
            ));
          },
        ),
    );
  }
}
