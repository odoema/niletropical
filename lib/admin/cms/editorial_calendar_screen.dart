import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/supabase_service.dart';

class _CalendarEvent {
  const _CalendarEvent({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    required this.scheduledAt,
    this.byline,
  });
  final String id;
  final String title;
  final String status;
  final String type;
  final DateTime scheduledAt;
  final String? byline;
}

class _CalendarHoliday {
  const _CalendarHoliday({
    required this.date,
    required this.name,
    required this.category,
    this.description,
  });
  final DateTime date;
  final String name;
  final String category;
  final String? description;
}

class EditorialCalendarScreen extends StatefulWidget {
  const EditorialCalendarScreen({super.key});
  @override State<EditorialCalendarScreen> createState() => _EditorialCalendarScreenState();
}

class _EditorialCalendarScreenState extends State<EditorialCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  bool _saving = false;
  bool _showHolidays = true;
  bool _showObservances = true;
  String _statusFilter = 'all';
  String _holidayFilter = 'all';
  bool _canReschedule = false;
  List<_CalendarEvent> _events = const [];

  static final List<_CalendarHoliday> _holidays = [
    _CalendarHoliday(date: DateTime(2026, 1, 1), name: "New Year's Day", category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 1, 15), name: 'General Election Day', category: 'uganda_public', description: 'Public holiday declared for participation in the 2026 general elections.'),
    _CalendarHoliday(date: DateTime(2026, 1, 16), name: 'General Election Day', category: 'uganda_public', description: 'Public holiday declared for participation in the 2026 general elections.'),
    _CalendarHoliday(date: DateTime(2026, 1, 26), name: 'NRM Liberation Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 2, 16), name: 'Archbishop Janani Luwum Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 3, 8), name: "International Women's Day", category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 3, 20), name: 'Eid-Ul-Fitr', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 4, 3), name: 'Good Friday', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 4, 6), name: 'Easter Monday', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 5, 1), name: 'Labour Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 5, 12), name: 'Presidential Inauguration Public Holiday', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 5, 27), name: 'Eid Al Adha', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 6, 3), name: "Uganda Martyrs' Day", category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 6, 9), name: 'National Heroes Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 7, 28), name: 'Local Elections Public Holiday', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 10, 9), name: 'Uganda Independence Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 12, 25), name: 'Christmas Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 12, 26), name: 'Boxing Day', category: 'uganda_public'),
    _CalendarHoliday(date: DateTime(2026, 3, 22), name: 'World Water Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 4, 22), name: 'Earth Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 5, 20), name: 'World Bee Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 5, 21), name: 'International Tea Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 5, 25), name: 'Africa Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 6, 5), name: 'World Environment Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 6, 7), name: 'World Food Safety Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 8, 12), name: 'International Youth Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 9, 27), name: 'World Tourism Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 10, 10), name: 'World Mental Health Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 10, 16), name: 'World Food Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 12, 5), name: 'World Soil Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 12, 10), name: 'Human Rights Day', category: 'global_observance'),
    _CalendarHoliday(date: DateTime(2026, 7, 25), name: 'National Cleaning Day', category: 'uganda_cultural', description: 'Uganda began a nationwide monthly sanitation exercise; the last Saturday of each month is used as the recurring cleaning-day window.'),
  ];

  @override void initState() { super.initState(); _initialize(); }

  Future<void> _initialize() async {
    try {
      final roles = await AuthService.rolesForCurrentUser();
      _canReschedule = roles.contains('manager') || roles.contains('super_admin');
    } finally {
      await _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final start = DateTime(_month.year, _month.month).toUtc().toIso8601String();
      final end = DateTime(_month.year, _month.month + 1).toUtc().toIso8601String();
      final rows = await SupabaseService.client
          .from('publishing_items')
          .select('id,title,status,scheduled_at,content_type,byline')
          .gte('scheduled_at', start)
          .lt('scheduled_at', end)
          .order('scheduled_at');
      final parsed = <_CalendarEvent>[];
      for (final raw in List<Map<String, dynamic>>.from(rows)) {
        final date = DateTime.tryParse(raw['scheduled_at']?.toString() ?? '');
        if (date == null) continue;
        parsed.add(_CalendarEvent(
          id: raw['id'].toString(),
          title: raw['title']?.toString() ?? 'Untitled',
          status: raw['status']?.toString() ?? 'draft',
          type: raw['content_type']?.toString() ?? 'content',
          scheduledAt: date.toLocal(),
          byline: raw['byline']?.toString(),
        ));
      }
      if (mounted) setState(() => _events = parsed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calendar could not load: ' + e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_CalendarEvent> _eventsForDay(DateTime day) => _events.where((x) {
        final sameDay = x.scheduledAt.year == day.year &&
            x.scheduledAt.month == day.month &&
            x.scheduledAt.day == day.day;
        return sameDay && (_statusFilter == 'all' || x.status == _statusFilter);
      }).toList();

  List<_CalendarHoliday> _holidaysForDay(DateTime day) => _holidays.where((x) {
        final sameDay = x.date.year == day.year && x.date.month == day.month && x.date.day == day.day;
        if (!sameDay) return false;
        if (x.category == 'uganda_public' || x.category == 'uganda_cultural') {
          return _showHolidays && (_holidayFilter == 'all' || _holidayFilter == x.category);
        }
        return _showObservances && (_holidayFilter == 'all' || _holidayFilter == x.category);
      }).toList();

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  void _goToday() {
    setState(() => _month = DateTime(DateTime.now().year, DateTime.now().month));
    _load();
  }

  Future<void> _moveEvent(_CalendarEvent event, DateTime targetDay) async {
    if (!_canReschedule || _saving) return;
    final original = event.scheduledAt;
    final value = DateTime(targetDay.year, targetDay.month, targetDay.day, original.hour, original.minute);
    if (_sameDate(value, original)) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('publishing_items')
          .update({'scheduled_at': value.toUtc().toIso8601String()}).eq('id', event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved “' + event.title + '” to ' + _shortDate(value) + '.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not move publication: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDay(DateTime day) async {
    final items = _eventsForDay(day);
    final holidays = _holidaysForDay(day);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_longDate(day)),
        content: SizedBox(
          width: 680,
          height: 500,
          child: ListView(
            children: [
              if (holidays.isNotEmpty) ...[
                Text('Calendar context', style: NileTypography.titleSmall),
                const SizedBox(height: 8),
                ...holidays.map((h) => ListTile(
                      dense: true,
                      leading: Icon(h.category == 'uganda_public' ? Icons.flag_outlined : Icons.public_outlined),
                      title: Text(h.name),
                      subtitle: Text(h.description ?? _categoryLabel(h.category)),
                    )),
                const Divider(),
              ],
              Text(items.isEmpty ? 'No planned publications' : 'Planned publications', style: NileTypography.titleSmall),
              const SizedBox(height: 8),
              ...items.map((x) => ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: Text(x.title),
                    subtitle: Text(_time(x.scheduledAt) + ' · ' + x.type.replaceAll('_', ' ') + ' · ' + x.status.replaceAll('_', ' ')),
                    trailing: IconButton(
                      tooltip: 'Open in Publishing Studio',
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/admin/cms/publishing?item=' + Uri.encodeComponent(x.id));
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); context.push('/admin/cms/publishing'); },
            child: const Text('Publishing Studio'),
          ),
          FilledButton.icon(
            onPressed: () { Navigator.pop(context); context.push('/admin/cms/publishing'); },
            icon: const Icon(Icons.add),
            label: const Text('Plan content'),
          ),
        ],
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) cells.add(const SizedBox.shrink());
    for (var day = 1; day <= days; day++) cells.add(_dayCell(DateTime(_month.year, _month.month, day)));
    while (cells.length < 42) cells.add(const SizedBox.shrink());

    return Scaffold(
      appBar: NileAppBar(
        title: 'Editorial Calendar',
        actions: [
          IconButton(onPressed: _goToday, tooltip: 'Today', icon: const Icon(Icons.today_outlined)),
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(NileSpacing.md, NileSpacing.sm, NileSpacing.md, 0),
            child: _toolbar(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(NileSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => Expanded(child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(d, textAlign: TextAlign.center, style: NileTypography.labelSmall),
                            )))
                        .toList(),
                  ),
                  if (_loading || _saving) const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      children: cells,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() => Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(MaterialLocalizations.of(context).formatMonthYear(_month), textAlign: TextAlign.center, style: NileTypography.titleLarge),
              ),
              IconButton(onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'in_review', child: Text('In review')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                ],
                onChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
              ),
              DropdownButton<String>(
                value: _holidayFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All calendar dates')),
                  DropdownMenuItem(value: 'uganda_public', child: Text('Uganda public holidays')),
                  DropdownMenuItem(value: 'uganda_cultural', child: Text('Uganda cultural')),
                  DropdownMenuItem(value: 'global_observance', child: Text('Global observances')),
                ],
                onChanged: (value) => setState(() => _holidayFilter = value ?? 'all'),
              ),
              FilterChip(label: const Text('Uganda holidays'), selected: _showHolidays, onSelected: (value) => setState(() => _showHolidays = value)),
              FilterChip(label: const Text('Global observances'), selected: _showObservances, onSelected: (value) => setState(() => _showObservances = value)),
              OutlinedButton.icon(onPressed: () => context.push('/admin/cms/publishing'), icon: const Icon(Icons.add), label: const Text('Plan content')),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _canReschedule
                  ? 'Drag scheduled content to another day to reschedule it.'
                  : 'Calendar is view-only for your role. Managers and super admins can reschedule by drag and drop.',
              style: NileTypography.bodySmall,
            ),
          ),
        ],
      );

  Widget _dayCell(DateTime day) {
    final items = _eventsForDay(day);
    final holidays = _holidaysForDay(day);
    final isToday = _sameDate(day, DateTime.now());

    Widget cell = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? NileColors.primary : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(day.day.toString(), style: NileTypography.labelSmall.copyWith(color: isToday ? Colors.white : null, fontWeight: isToday ? FontWeight.w700 : null)),
                ),
                const Spacer(),
                if (holidays.isNotEmpty)
                  Tooltip(message: holidays.map((x) => x.name).join('\\n'), child: const Icon(Icons.flag_outlined, size: 15)),
              ],
            ),
            if (holidays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 3),
                child: Text(holidays.first.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: NileTypography.labelSmall),
              ),
            Expanded(
              child: ListView(physics: const NeverScrollableScrollPhysics(), children: items.take(3).map(_eventChip).toList()),
            ),
            if (items.length > 3) Text('+' + (items.length - 3).toString() + ' more', style: NileTypography.labelSmall),
          ],
        ),
      ),
    );

    cell = DragTarget<_CalendarEvent>(
      onWillAcceptWithDetails: (_) => _canReschedule,
      onAcceptWithDetails: (details) => _moveEvent(details.data, day),
      builder: (context, candidate, rejected) {
        if (candidate.isEmpty) return cell;
        return DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: NileColors.primary, width: 2), borderRadius: NileRadius.borderMd),
          child: cell,
        );
      },
    );

    return InkWell(borderRadius: NileRadius.borderMd, onTap: () => _showDay(day), child: cell);
  }

  Widget _eventChip(_CalendarEvent event) {
    final chip = Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(color: NileColors.primaryContainer, borderRadius: BorderRadius.circular(6)),
      child: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: NileTypography.labelSmall.copyWith(color: NileColors.primary)),
    );
    if (!_canReschedule) return chip;
    return Draggable<_CalendarEvent>(
      data: event,
      feedback: Material(color: Colors.transparent, child: SizedBox(width: 180, child: NileCard(child: Padding(padding: const EdgeInsets.all(8), child: Text(event.title))))),
      childWhenDragging: Opacity(opacity: .35, child: chip),
      child: chip,
    );
  }

  static bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static String _shortDate(DateTime d) => d.day.toString().padLeft(2, '0') + '/' + d.month.toString().padLeft(2, '0') + '/' + d.year.toString();
  static String _longDate(DateTime d) => d.day.toString() + ' ' + _monthName(d.month) + ' ' + d.year.toString();
  static String _monthName(int month) => const ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month];
  static String _time(DateTime d) => d.hour.toString().padLeft(2, '0') + ':' + d.minute.toString().padLeft(2, '0');
  static String _categoryLabel(String value) {
    switch (value) {
      case 'uganda_public': return 'Uganda public holiday';
      case 'uganda_cultural': return 'Uganda cultural/editorial date';
      case 'global_observance': return 'Global observance';
      default: return 'Calendar date';
    }
  }
}
