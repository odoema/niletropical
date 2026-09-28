import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/supabase_service.dart';

class EditorialCalendarScreen extends StatefulWidget {
  const EditorialCalendarScreen({super.key});
  @override State<EditorialCalendarScreen> createState() => _EditorialCalendarScreenState();
}

class _EditorialCalendarScreenState extends State<EditorialCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _weekStart = _monday(DateTime.now());
  bool _loading = true;
  bool _saving = false;
  bool _weekView = false;
  bool _showHolidays = true;
  bool _showObservances = true;
  bool _canManage = false;
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  String _channelFilter = 'all';
  List<Map<String,dynamic>> _items = [];
  List<Map<String,dynamic>> _dates = [];
  List<Map<String,dynamic>> _campaigns = [];
  Map<String,List<String>> _channels = {};

  @override void initState() { super.initState(); _initialize(); }

  Future<void> _initialize() async {
    final roles = await AuthService.rolesForCurrentUser();
    _canManage = roles.contains('manager') || roles.contains('super_admin');
    await _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final start = DateTime(_month.year, _month.month);
      final end = DateTime(_month.year, _month.month + 1);
      final rows = await SupabaseService.client.from('publishing_items')
          .select('id,title,status,scheduled_at,content_type,byline,updated_at')
          .order('scheduled_at');
      final items = List<Map<String,dynamic>>.from(rows).where((x) {
        final s = x['scheduled_at']?.toString();
        if (s == null) return true;
        final d = DateTime.tryParse(s)?.toLocal();
        return d != null && d.isBefore(end);
      }).toList();

      final targetRows = await SupabaseService.client.from('publishing_targets')
          .select('item_id,channel,status,scheduled_at');
      final channels = <String,List<String>>{};
      for (final row in List<Map<String,dynamic>>.from(targetRows)) {
        final id = row['item_id']?.toString();
        final channel = row['channel']?.toString();
        if (id != null && channel != null) {
          (channels[id] ??= []).add(channel);
        }
      }

      final dates = await SupabaseService.client.from('editorial_calendar_dates')
          .select('id,date,name,category,description,recurring_rule')
          .eq('active', true)
          .gte('date', DateTime(start.year, start.month - 1, 1).toIso8601String().substring(0,10))
          .lte('date', DateTime(end.year, end.month + 1, 0).toIso8601String().substring(0,10));

      final campaigns = await SupabaseService.client.from('editorial_campaigns')
          .select('id,name,theme,description,starts_on,ends_on,status')
          .order('starts_on');

      if (!mounted) return;
      setState(() {
        _items = items;
        _channels = channels;
        _dates = List<Map<String,dynamic>>.from(dates);
        _campaigns = List<Map<String,dynamic>>.from(campaigns);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calendar could not load: ' + e.toString())),
      );
    }
  }

  bool _matches(Map<String,dynamic> item) {
    if (_statusFilter != 'all' && item['status'] != _statusFilter) return false;
    if (_typeFilter != 'all' && item['content_type'] != _typeFilter) return false;
    if (_channelFilter != 'all' &&
        !(_channels[item['id']?.toString()] ?? const <String>[]).contains(_channelFilter)) return false;
    return true;
  }

  List<Map<String,dynamic>> get _unscheduled =>
      _items.where((x) => x['scheduled_at'] == null && _matches(x)).toList();

  List<Map<String,dynamic>> _itemsForDay(DateTime day) => _items.where((x) {
    if (x['scheduled_at'] == null || !_matches(x)) return false;
    final d = DateTime.tryParse(x['scheduled_at'].toString())?.toLocal();
    return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
  }).toList();

  List<Map<String,dynamic>> _datesForDay(DateTime day) => _dates.where((x) {
    final d = DateTime.tryParse(x['date']?.toString() ?? '');
    if (d == null || d.year != day.year || d.month != day.month || d.day != day.day) return false;
    final category = x['category']?.toString();
    return (category == 'uganda_public' || category == 'uganda_cultural')
        ? _showHolidays
        : _showObservances;
  }).toList();

  List<Map<String,dynamic>> _campaignsForDay(DateTime day) => _campaigns.where((x) {
    final start = DateTime.tryParse(x['starts_on']?.toString() ?? '');
    final end = DateTime.tryParse(x['ends_on']?.toString() ?? '');
    return start != null && end != null && !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  Future<void> _scheduleItem(Map<String,dynamic> item, DateTime day) async {
    if (!_canManage || _saving) return;
    setState(() => _saving = true);
    try {
      final old = item['scheduled_at'];
      final original = old == null
          ? DateTime(day.year, day.month, day.day, 9)
          : DateTime.parse(old.toString()).toLocal();
      final value = DateTime(day.year, day.month, day.day, original.hour, original.minute).toUtc().toIso8601String();
      await SupabaseService.client.rpc('reschedule_publishing_item', params: {
        'p_item_id': item['id'],
        'p_scheduled_at': value,
        'p_note': 'Planned or rescheduled from Editorial Calendar',
      });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule publication: ' + e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assignItemToCampaign(Map<String,dynamic> item) async { if (!_canManage || _campaigns.isEmpty) return; String? selected; final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: const Text('Add to campaign / theme'), content: DropdownButtonFormField<String>(value: selected, decoration: const InputDecoration(labelText: 'Campaign'), items: _campaigns.map((c) => DropdownMenuItem<String>(value: c['id'].toString(), child: Text(c['name']?.toString() ?? ''))).toList(), onChanged: (v) => setDialogState(() => selected = v)), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: selected == null ? null : () => Navigator.pop(dialogContext, true), child: const Text('Add'))]))); if (ok == true && selected != null) { try { await SupabaseService.client.from('editorial_campaign_items').upsert({'campaign_id': selected, 'item_id': item['id']}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content added to campaign.'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not assign campaign: ' + e.toString()))); } } }

  Future<void> _createCampaign() async {
    if (!_canManage) return;
    final name = TextEditingController();
    final theme = TextEditingController();
    final description = TextEditingController();
    DateTime startDate = DateTime(_month.year, _month.month, 1);
    DateTime endDate = DateTime(_month.year, _month.month + 1, 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New campaign / theme'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Campaign name'),
                    ),
                    TextField(
                      controller: theme,
                      decoration: const InputDecoration(labelText: 'Theme'),
                    ),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2035),
                                initialDate: startDate,
                              );
                              if (picked != null) {
                                setDialogState(() => startDate = picked);
                              }
                            },
                            child: Text('Start: ' + _date(startDate)),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: startDate,
                                lastDate: DateTime(2035),
                                initialDate: endDate,
                              );
                              if (picked != null) {
                                setDialogState(() => endDate = picked);
                              }
                            },
                            child: Text('End: ' + _date(endDate)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        final uid = SupabaseService.client.auth.currentUser?.id;
        await SupabaseService.client.from('editorial_campaigns').insert({
          'name': name.text.trim(),
          'theme': theme.text.trim(),
          'description': description.text.trim(),
          'starts_on': _date(startDate),
          'ends_on': _date(endDate),
          'created_by': uid,
          'updated_by': uid,
        });
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create campaign: ' + e.toString())),
          );
        }
      }
    }

    name.dispose();
    theme.dispose();
    description.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: NileAppBar(title: 'Editorial Calendar', actions: [
        IconButton(onPressed: _goToday, tooltip: 'Today', icon: const Icon(Icons.today_outlined)),
        IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
      ]),
      body: Column(children: [
        _toolbar(),
        if (_loading || _saving) const LinearProgressIndicator(),
        Expanded(child: Row(children: [
          SizedBox(width: 310, child: _queue()),
          const VerticalDivider(width: 1),
          Expanded(child: Padding(padding: const EdgeInsets.all(10), child: _calendar())),
        ])),
      ]),
    );
  }

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Column(children: [
      Row(children: [
        IconButton(onPressed: () => _weekView ? _moveWeek(-1) : _moveMonth(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(
          _weekView ? _date(_weekStart) + ' → ' + _date(_weekStart.add(const Duration(days: 6))) : MaterialLocalizations.of(context).formatMonthYear(_month),
          textAlign: TextAlign.center, style: NileTypography.titleLarge,
        )),
        IconButton(onPressed: () => _weekView ? _moveWeek(1) : _moveMonth(1), icon: const Icon(Icons.chevron_right)),
        ToggleButtons(
          isSelected: [!_weekView, _weekView],
          onPressed: (i) => setState(() => _weekView = i == 1),
          children: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Month')),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Week')),
          ],
        ),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _dropdown('Status', _statusFilter, const ['all','draft','in_review','approved','scheduled','published']),
        _dropdown('Type', _typeFilter, const ['all','news_story','social_post','press_release','announcement','photo_story','video_story']),
        _dropdown('Channel', _channelFilter, const ['all','website','facebook','instagram','linkedin','x','youtube','whatsapp','newsletter','press']),
        FilterChip(label: const Text('Uganda dates'), selected: _showHolidays, onSelected: (v) => setState(() => _showHolidays = v)),
        FilterChip(label: const Text('Global observances'), selected: _showObservances, onSelected: (v) => setState(() => _showObservances = v)),
        if (_canManage) OutlinedButton.icon(
          onPressed: _createCampaign,
          icon: const Icon(Icons.flag_outlined), label: const Text('Campaign / Theme'),
        ),
      ]),
      const SizedBox(height: 5),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _canManage
              ? 'Drag unscheduled or scheduled content onto a date. Scheduling is recorded in the publishing audit.'
              : 'Calendar is view-only for your role.',
          style: NileTypography.bodySmall,
        ),
      ),
    ]),
  );

  Widget _dropdown(String label, String value, List<String> values) => DropdownButton<String>(
    value: value,
    items: values.map((v) => DropdownMenuItem(
      value: v,
      child: Text(label + ': ' + (v == 'all' ? 'All' : v.replaceAll('_', ' '))),
    )).toList(),
    onChanged: (v) => setState(() {
      if (label == 'Status') _statusFilter = v ?? 'all';
      if (label == 'Type') _typeFilter = v ?? 'all';
      if (label == 'Channel') _channelFilter = v ?? 'all';
    }),
  );

  Widget _queue() => Container(
    color: NileColors.surface,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: Text('Unscheduled content (' + _unscheduled.length.toString() + ')', style: NileTypography.titleMedium)),
          IconButton(onPressed: () => context.push('/admin/cms/publishing'), icon: const Icon(Icons.add), tooltip: 'Create content'),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.all(8), children: [
        ..._unscheduled.map(_queueCard),
        if (_unscheduled.isEmpty) const Padding(
          padding: EdgeInsets.all(16), child: Text('No unscheduled content matches the filters.'),
        ),
        if (_campaigns.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Campaigns & themes', style: NileTypography.titleSmall),
          ..._campaigns.map((c) => ListTile(
            dense: true, leading: const Icon(Icons.flag_outlined),
            title: Text(c['name']?.toString() ?? ''),
            subtitle: Text((c['theme']?.toString() ?? '') + ' · ' + c['starts_on'].toString() + ' → ' + c['ends_on'].toString()),
          )),
        ],
      ])),
    ]),
  );

  Widget _queueCard(Map<String,dynamic> item) {
    final id = item['id'].toString();
    final card = NileCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(8), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['title']?.toString() ?? 'Untitled', maxLines: 2, overflow: TextOverflow.ellipsis, style: NileTypography.titleSmall),
          Text(
            (item['content_type']?.toString() ?? 'content') + ' · ' + (item['status']?.toString() ?? 'draft'),
            style: NileTypography.bodySmall,
          ),
          if ((_channels[id] ?? []).isNotEmpty) Text((_channels[id] ?? []).join(', '), style: NileTypography.labelSmall),
          if (_canManage && _campaigns.isNotEmpty) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _assignItemToCampaign(item), icon: const Icon(Icons.campaign_outlined, size: 16), label: const Text('Campaign'))),
        ],
      )),
    );
    final open = InkWell(onTap: () => context.push('/admin/cms/publishing?item=' + Uri.encodeComponent(id)), child: card);
    if (!_canManage) return open;
    return Draggable<Map<String,dynamic>>(
      data: item,
      feedback: Material(color: Colors.transparent, child: SizedBox(width: 260, child: card)),
      childWhenDragging: Opacity(opacity: .35, child: open),
      child: open,
    );
  }

  Widget _calendar() {
    final days = _weekView ? _weekDays() : _monthDays();
    return Column(children: [
      Row(children: const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
          .map((x) => Expanded(child: Center(child: Padding(padding: EdgeInsets.all(4), child: Text(x))))).toList()),
      Expanded(child: GridView.count(
        crossAxisCount: 7,
        childAspectRatio: _weekView ? .9 : 1.05,
        crossAxisSpacing: 4, mainAxisSpacing: 4,
        children: days.map(_dayCell).toList(),
      )),
    ]);
  }

  List<DateTime> _monthDays() {
    final first = DateTime(_month.year, _month.month, 1);
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final result = <DateTime>[];
    for (var i = 0; i < leading; i++) result.add(first.subtract(Duration(days: leading - i)));
    for (var i = 1; i <= count; i++) result.add(DateTime(_month.year, _month.month, i));
    while (result.length < 42) result.add(result.last.add(const Duration(days: 1)));
    return result;
  }

  List<DateTime> _weekDays() => List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  static DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  void _moveWeek(int delta) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * delta)));
    _load();
  }

  Widget _dayCell(DateTime day) {
    final items = _itemsForDay(day);
    final dates = _datesForDay(day);
    final campaigns = _campaignsForDay(day);
    final today = DateTime.now();
    final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

    Widget content = Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(5), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(day.day.toString(), style: NileTypography.labelSmall.copyWith(fontWeight: isToday ? FontWeight.bold : null)),
            const Spacer(),
            if (dates.isNotEmpty) const Icon(Icons.flag_outlined, size: 14),
            if (campaigns.isNotEmpty) const Icon(Icons.campaign_outlined, size: 14),
          ]),
          if (dates.isNotEmpty) Text(dates.first['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: NileTypography.labelSmall),
          if (campaigns.isNotEmpty) Text(campaigns.first['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: NileTypography.labelSmall),
          Expanded(child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: items.take(_weekView ? 8 : 3).map(_eventChip).toList(),
          )),
          if (items.length > (_weekView ? 8 : 3))
            Text('+' + (items.length - (_weekView ? 8 : 3)).toString() + ' more', style: NileTypography.labelSmall),
        ],
      )),
    );

    if (!_canManage) return InkWell(onTap: () => _showDay(day), child: content);
    return DragTarget<Map<String,dynamic>>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _scheduleItem(details.data, day),
      builder: (context, candidate, rejected) => InkWell(
        onTap: () => _showDay(day),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: candidate.isNotEmpty ? Border.all(color: NileColors.primary, width: 2) : null,
            borderRadius: NileRadius.borderMd,
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _eventChip(Map<String,dynamic> item) {
    final chip = Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: NileColors.primaryContainer, borderRadius: BorderRadius.circular(5)),
      child: Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: NileTypography.labelSmall.copyWith(color: NileColors.primary)),
    );
    if (!_canManage) return chip;
    return Draggable<Map<String,dynamic>>(
      data: item,
      feedback: Material(color: Colors.transparent, child: SizedBox(width: 180, child: NileCard(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['title']?.toString() ?? ''))))),
      childWhenDragging: Opacity(opacity: .3, child: chip),
      child: chip,
    );
  }

  Future<void> _showDay(DateTime day) async {
    final items = _itemsForDay(day);
    final dates = _datesForDay(day);
    final campaigns = _campaignsForDay(day);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_longDate(day)),
        content: SizedBox(width: 700, height: 520, child: ListView(children: [
          if (dates.isNotEmpty) ...[
            Text('Calendar opportunities', style: NileTypography.titleSmall),
            ...dates.map((d) => ListTile(
              dense: true, leading: const Icon(Icons.flag_outlined),
              title: Text(d['name'].toString()),
              subtitle: Text(d['description']?.toString() ?? d['category'].toString()),
            )),
          ],
          if (campaigns.isNotEmpty) ...[
            Text('Campaigns / themes', style: NileTypography.titleSmall),
            ...campaigns.map((c) => ListTile(
              dense: true, leading: const Icon(Icons.campaign_outlined),
              title: Text(c['name'].toString()),
              subtitle: Text(c['theme']?.toString() ?? ''),
            )),
          ],
          const SizedBox(height: 8),
          Text(items.isEmpty ? 'No planned publications' : 'Planned publications', style: NileTypography.titleSmall),
          ...items.map((x) => ListTile(
            title: Text(x['title'].toString()),
            subtitle: Text((x['content_type'] ?? 'content').toString() + ' · ' + (x['status'] ?? 'draft').toString()),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.pop(context);
                context.push('/admin/cms/publishing?item=' + Uri.encodeComponent(x['id'].toString()));
              },
            ),
          )),
        ])),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); context.push('/admin/cms/publishing'); }, child: const Text('Publishing Studio')),
        ],
      ),
    );
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() { _month = DateTime(now.year, now.month); _weekStart = _monday(now); });
    _load();
  }

  static String _date(DateTime d) => d.year.toString().padLeft(4,'0') + '-' + d.month.toString().padLeft(2,'0') + '-' + d.day.toString().padLeft(2,'0');
  static String _longDate(DateTime d) => d.day.toString() + ' ' + _monthName(d.month) + ' ' + d.year.toString();
  static String _monthName(int month) => const ['','January','February','March','April','May','June','July','August','September','October','November','December'][month];
}
