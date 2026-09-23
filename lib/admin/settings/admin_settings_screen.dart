import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _config = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() { _loading = false; _error = 'Supabase is not configured.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        SupabaseService.client.schema('nile_admin').from('modules').select().order('name'),
        SupabaseService.client.schema('nile_admin').from('project_config').select().order('key'),
      ]);
      if (!mounted) return;
      setState(() {
        _modules = List<Map<String, dynamic>>.from(results[0]);
        _config = List<Map<String, dynamic>>.from(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _toggleModule(Map<String, dynamic> row, bool value) async {
    try {
      final query = SupabaseService.client.schema('nile_admin').from('modules').update({'is_enabled': value});
      final id = row['id'];
      if (id != null) {
        await query.eq('id', id);
      } else {
        await query.eq('module_key', (row['module_key'] ?? row['key']).toString());
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Module update failed: ' + e.toString()), backgroundColor: NileColors.error));
    }
  }

  Future<void> _editConfig(Map<String, dynamic> row) async {
    final key = row['key']?.toString() ?? '';
    final ctrl = TextEditingController(text: (row['value'] ?? row['config_value'] ?? '').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ' + key),
        content: TextField(controller: ctrl, maxLines: 5, decoration: const InputDecoration(labelText: 'Value')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    try {
      final payload = row.containsKey('value') ? {'value': ctrl.text.trim()} : {'config_value': ctrl.text.trim()};
      await SupabaseService.client.schema('nile_admin').from('project_config').update(payload).eq('key', key);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Config update failed: ' + e.toString()), backgroundColor: NileColors.error));
    } finally { ctrl.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const NileLoadingState() : _error != null ? NileErrorState(message: _error!, onRetry: _load) :
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Modules', style: NileTypography.headlineSmall),
            const SizedBox(height: 8),
            if (_modules.isEmpty) const Text('No module configuration found.')
            else ..._modules.map((r) => Card(child: SwitchListTile(
              title: Text((r['name'] ?? r['module_key'] ?? r['key'] ?? 'Module').toString()),
              subtitle: Text((r['description'] ?? '').toString()),
              value: r['is_enabled'] == true,
              onChanged: (v) => _toggleModule(r, v),
            ))),
            const SizedBox(height: 24),
            Text('Project configuration', style: NileTypography.headlineSmall),
            const SizedBox(height: 8),
            if (_config.isEmpty) const Text('No project configuration found.')
            else ..._config.map((r) => Card(child: ListTile(
              title: Text((r['label'] ?? r['key'] ?? 'Setting').toString()),
              subtitle: Text((r['value'] ?? r['config_value'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editConfig(r),
            ))),
          ],
        ),
    );
  }
}
