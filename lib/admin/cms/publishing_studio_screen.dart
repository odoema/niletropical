import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class PublishingStudioScreen extends StatefulWidget {
  const PublishingStudioScreen({super.key});
  @override State<PublishingStudioScreen> createState() => _PublishingStudioScreenState();
}

class _PublishingStudioScreenState extends State<PublishingStudioScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseService.client.from('publishing_items')
        .select('id,title,content_type,status,byline,scheduled_at,updated_at,slug,source_note,cover_media_path,tags')
        .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() { _items = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publishing workspace could not load: ' + e.toString())));
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items.where((x) {
      final status = x['status']?.toString() ?? '';
      final title = x['title']?.toString().toLowerCase() ?? '';
      return (_filter == 'all' || status == _filter) && (q.isEmpty || title.contains(q));
    }).toList();
  }

  Future<void> _newItem() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const _PublishingEditor());
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: NileAppBar(title: 'Publishing Studio', actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newItem, icon: const Icon(Icons.edit_outlined), label: const Text('New story'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(NileSpacing.md),
          children: [
            Text('Newsroom & social publishing', style: NileTypography.headlineSmall),
            const SizedBox(height: 6),
            Text('Draft, edit, review, schedule and record publication across social and media channels.', style: NileTypography.bodyMedium),
            const SizedBox(height: NileSpacing.md),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search stories, releases and posts…'),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: ['all','draft','in_review','approved','scheduled','published'].map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s == 'all' ? 'All' : s.replaceAll('_',' ')),
                  selected: _filter == s,
                  onSelected: (_) => setState(() => _filter = s),
                ),
              )).toList()),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && visible.isEmpty)
              const NileCard(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No publishing items yet. Create the first story or social post.')))),
            ...visible.map(_itemCard),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'draft';
    final scheduled = item['scheduled_at']?.toString();
    return NileCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () async {
        final saved = await showDialog<bool>(context: context, builder: (_) => _PublishingEditor(item: item));
        if (saved == true) _load();
      },
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: NileColors.primaryContainer, borderRadius: NileRadius.borderMd),
          child: Icon(_iconFor(item['content_type']?.toString()), color: NileColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title']?.toString() ?? 'Untitled', style: NileTypography.titleMedium),
          const SizedBox(height: 3),
          Text((item['content_type']?.toString() ?? 'content') + ' · ' + (item['byline']?.toString() ?? 'No byline'), style: NileTypography.bodySmall),
          if (scheduled != null) Text('Scheduled: ' + scheduled, style: NileTypography.bodySmall),
        ])),
        _StatusPill(status), const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: NileColors.textTertiary),
      ]),
    );
  }

  static IconData _iconFor(String? type) {
    switch (type) {
      case 'news_story': return Icons.article_outlined;
      case 'press_release': return Icons.campaign_outlined;
      case 'photo_story': return Icons.photo_camera_outlined;
      case 'video_story': return Icons.videocam_outlined;
      case 'announcement': return Icons.announcement_outlined;
      default: return Icons.forum_outlined;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: NileColors.primaryContainer, borderRadius: BorderRadius.circular(20)),
    child: Text(status.replaceAll('_',' '), style: NileTypography.labelSmall.copyWith(color: NileColors.primary)),
  );
}

class _PublishingEditor extends StatefulWidget {
  const _PublishingEditor({this.item});
  final Map<String, dynamic>? item;
  @override State<_PublishingEditor> createState() => _PublishingEditorState();
}

class _PublishingEditorState extends State<_PublishingEditor> {
  late final TextEditingController _title, _body, _caption, _byline, _tags, _source, _slug, _cover;
  String _type = 'social_post', _status = 'draft';
  final Set<String> _channels = {'facebook', 'instagram'};
  DateTime? _scheduledAt;
  bool _saving = false;

  @override void initState() {
    super.initState();
    final x = widget.item;
    _title = TextEditingController(text: x?['title']?.toString() ?? '');
    _body = TextEditingController(text: x?['body']?.toString() ?? '');
    _caption = TextEditingController(text: x?['caption']?.toString() ?? '');
    _byline = TextEditingController(text: x?['byline']?.toString() ?? '');
    _tags = TextEditingController(text: x?['tags'] is List ? (x!['tags'] as List).join(', ') : '');
    _source = TextEditingController(text: x?['source_note']?.toString() ?? '');
    _slug = TextEditingController(text: x?['slug']?.toString() ?? '');
    _cover = TextEditingController(text: x?['cover_media_path']?.toString() ?? '');
    _type = x?['content_type']?.toString() ?? 'social_post';
    _status = x?['status']?.toString() ?? 'draft';
    final raw = x?['scheduled_at']?.toString();
    _scheduledAt = raw == null ? null : DateTime.tryParse(raw);
  }

  @override void dispose() { _title.dispose(); _body.dispose(); _caption.dispose(); _byline.dispose(); _tags.dispose(); _source.dispose(); _slug.dispose(); _cover.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': _title.text.trim(), 'slug': _slug.text.trim().isEmpty ? null : _slug.text.trim(), 'content_type': _type, 'body': _body.text.trim(),
        'caption': _caption.text.trim(), 'byline': _byline.text.trim(), 'source_note': _source.text.trim(), 'cover_media_path': _cover.text.trim().isEmpty ? null : _cover.text.trim(),
        'tags': _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'status': _status, 'updated_by': SupabaseService.client.auth.currentUser?.id,
      };
      if (_status == 'scheduled' && _scheduledAt == null) {
        throw StateError('Choose a publishing date and time before scheduling.');
      }
      payload['scheduled_at'] = _scheduledAt?.toUtc().toIso8601String();
      payload['published_at'] = _status == 'published' ? DateTime.now().toUtc().toIso8601String() : null;
      String itemId;
      if (widget.item == null) {
        payload['created_by'] = SupabaseService.client.auth.currentUser?.id;
        final created = await SupabaseService.client.from('publishing_items').insert(payload).select('id').single();
        itemId = created['id'].toString();
      } else {
        itemId = widget.item!['id'].toString();
        await SupabaseService.client.from('publishing_items').update(payload).eq('id', itemId);
      }
      await SupabaseService.client.from('publishing_targets').delete().eq('item_id', itemId);
      await SupabaseService.client.from('publishing_item_events').insert({'item_id': itemId, 'actor_id': SupabaseService.client.auth.currentUser?.id, 'event_type': _status == 'in_review' ? 'submitted' : _status == 'approved' ? 'approved' : _status == 'scheduled' ? 'scheduled' : _status == 'published' ? 'published' : _status == 'archived' ? 'archived' : 'updated', 'to_status': _status});
      if (_channels.isNotEmpty) {
        await SupabaseService.client.from('publishing_targets').insert(
          _channels.map((channel) => {
            'item_id': itemId,
            'channel': channel,
            'headline': _title.text.trim(),
            'copy': _caption.text.trim().isEmpty ? _body.text.trim() : _caption.text.trim(),
            'status': _status == 'scheduled' ? 'scheduled' : (_status == 'published' ? 'published' : 'ready'),
            'scheduled_at': _scheduledAt?.toUtc().toIso8601String(),
            'published_at': _status == 'published' ? DateTime.now().toUtc().toIso8601String() : null,
          }).toList(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ' + e.toString())));
    }
  }

  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'New publishing item' : 'Edit publishing item'),
    content: SizedBox(width: 720, child: SingleChildScrollView(child: Column(children: [
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Headline / working title')),
      const SizedBox(height: 10), TextField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug')),
      const SizedBox(height: 10),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _type, decoration: const InputDecoration(labelText: 'Content type'),
        items: const [
          DropdownMenuItem(value: 'social_post', child: Text('Social media post')),
          DropdownMenuItem(value: 'news_story', child: Text('News story')),
          DropdownMenuItem(value: 'press_release', child: Text('Press release')),
          DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
          DropdownMenuItem(value: 'photo_story', child: Text('Photo story')),
          DropdownMenuItem(value: 'video_story', child: Text('Video story')),
        ], onChanged: (v) => setState(() => _type = v!),
      ),
      const SizedBox(height: 10),
      TextField(controller: _byline, decoration: const InputDecoration(labelText: 'Byline / journalist')),
      const SizedBox(height: 10), TextField(controller: _source, decoration: const InputDecoration(labelText: 'Source / attribution note')),
      const SizedBox(height: 10), TextField(controller: _cover, decoration: const InputDecoration(labelText: 'Cover media path (CMS library)')),
      const SizedBox(height: 10),
      TextField(controller: _caption, maxLines: 4, decoration: const InputDecoration(labelText: 'Social caption / standfirst')),
      const SizedBox(height: 10),
      TextField(controller: _body, minLines: 8, maxLines: 14, decoration: const InputDecoration(labelText: 'Story / editorial copy')),
      const SizedBox(height: 10),
      TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'uganda, shea, community')),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerLeft, child: Text('Publishing channels', style: NileTypography.titleSmall)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: ['website','facebook','instagram','linkedin','x','youtube','whatsapp','newsletter','press'].map(
          (channel) => FilterChip(
            label: Text(channel),
            selected: _channels.contains(channel),
            onSelected: (selected) => setState(() => selected ? _channels.add(channel) : _channels.remove(channel)),
          ),
        ).toList(),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDate: _scheduledAt ?? DateTime.now(),
          );
          if (date == null || !mounted) return;
          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()));
          if (time == null || !mounted) return;
          setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
        },
        icon: const Icon(Icons.schedule_outlined),
        label: Text(_scheduledAt == null ? 'Set publication date & time' : 'Schedule: ' + _scheduledAt!.toLocal().toString()),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _status, decoration: const InputDecoration(labelText: 'Workflow status'),
        items: const [
          DropdownMenuItem(value: 'draft', child: Text('Draft')),
          DropdownMenuItem(value: 'in_review', child: Text('In review')),
          DropdownMenuItem(value: 'approved', child: Text('Approved')),
          DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
          DropdownMenuItem(value: 'published', child: Text('Published')),
          DropdownMenuItem(value: 'archived', child: Text('Archived')),
        ], onChanged: (v) => setState(() => _status = v!),
      ),
    ]))),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save')),
    ],
  );
}
