import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class EditorialCalendarScreen extends StatefulWidget {
  const EditorialCalendarScreen({super.key});
  @override State<EditorialCalendarScreen> createState() => _EditorialCalendarScreenState();
}

class _EditorialCalendarScreenState extends State<EditorialCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = DateTime(_month.year, _month.month).toUtc().toIso8601String();
      final end = DateTime(_month.year, _month.month + 1).toUtc().toIso8601String();
      final rows = await SupabaseService.client.from('publishing_items')
          .select('id,title,status,scheduled_at,content_type,byline')
          .gte('scheduled_at', start).lt('scheduled_at', end).order('scheduled_at');
      if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calendar could not load: ' + e.toString())));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    final title = _month.year.toString() + '-' + _month.month.toString().padLeft(2, '0');
    return Scaffold(
      appBar: NileAppBar(title: 'Editorial Calendar', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: Padding(padding: const EdgeInsets.all(NileSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [IconButton(onPressed: () { setState(() => _month = DateTime(_month.year, _month.month - 1)); _load(); }, icon: const Icon(Icons.chevron_left)), Expanded(child: Text(title, textAlign: TextAlign.center, style: NileTypography.titleLarge)), IconButton(onPressed: () { setState(() => _month = DateTime(_month.year, _month.month + 1)); _load(); }, icon: const Icon(Icons.chevron_right))]),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading && _items.isEmpty) const Expanded(child: NileCard(child: Center(child: Text('Nothing scheduled for this month.')))),
        if (!_loading && _items.isNotEmpty) Expanded(child: ListView.separated(itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) {
          final x = _items[i]; final dt = DateTime.tryParse(x['scheduled_at']?.toString() ?? '')?.toLocal();
          final when = dt == null ? 'Unspecified time' : dt.toString();
          return NileCard(child: ListTile(leading: const Icon(Icons.event_outlined), title: Text(x['title']?.toString() ?? 'Untitled'), subtitle: Text(when + ' • ' + (x['content_type']?.toString() ?? 'content') + ' • ' + (x['status']?.toString() ?? 'scheduled')), trailing: Text(x['byline']?.toString() ?? '')));
        })),
      ])),
    );
  }
}
