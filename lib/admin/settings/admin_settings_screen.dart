import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;
  bool _autoRefresh = true;
  bool _compactAdmin = false;
  bool _showOperationalHints = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoRefresh = prefs.getBool('admin_auto_refresh') ?? true;
      _compactAdmin = prefs.getBool('admin_compact_layout') ?? false;
      _showOperationalHints = prefs.getBool('admin_operational_hints') ?? true;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        actions: [
          IconButton(
            tooltip: 'Reload settings',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Application', style: NileTypography.headlineSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Automatic refresh'),
                        subtitle: const Text('Allow admin screens to refresh their data when requested by the screen.'),
                        value: _autoRefresh,
                        onChanged: (value) {
                          setState(() => _autoRefresh = value);
                          _save('admin_auto_refresh', value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Compact admin layout'),
                        subtitle: const Text('Use a denser presentation where supported by an admin screen.'),
                        value: _compactAdmin,
                        onChanged: (value) {
                          setState(() => _compactAdmin = value);
                          _save('admin_compact_layout', value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Operational hints'),
                        subtitle: const Text('Show guidance and status information in administration screens.'),
                        value: _showOperationalHints,
                        onChanged: (value) {
                          setState(() => _showOperationalHints = value);
                          _save('admin_operational_hints', value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Backend status', style: NileTypography.headlineSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Env.isConfigured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                          color: Env.isConfigured ? NileColors.success : NileColors.error,
                        ),
                        title: const Text('Supabase connection'),
                        subtitle: Text(
                          Env.isConfigured
                              ? 'Production backend configuration is present.'
                              : 'Supabase credentials are missing from the build.',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.language_outlined),
                        title: const Text('Application environment'),
                        subtitle: Text(
                          Env.environment.name[0].toUpperCase() + Env.environment.name.substring(1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Important', style: NileTypography.headlineSmall),
                const SizedBox(height: 8),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Production Supabase credentials and database-level configuration are intentionally not editable from the browser. '
                      'This prevents an administrator from accidentally changing the live backend connection.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
