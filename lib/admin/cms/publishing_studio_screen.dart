import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/publishing_ai_service.dart';

class PublishingStudioScreen extends StatefulWidget {
  const PublishingStudioScreen({super.key, this.initialItemId});

  final String? initialItemId;
  @override State<PublishingStudioScreen> createState() => _PublishingStudioScreenState();
}

class _PublishingStudioScreenState extends State<PublishingStudioScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override void initState() {
    super.initState();
    _load();
    if (widget.initialItemId != null && widget.initialItemId!.isNotEmpty) _openInitialItem();
  }

  Future<void> _openInitialItem() async {
    try {
      final row = await SupabaseService.client.from('publishing_items').select('id,title').eq('id', widget.initialItemId!).single();
      if (mounted) await _openEditor(Map<String, dynamic>.from(row));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publishing item could not be opened: ' + e.toString())));
    }
  }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseService.client.from('publishing_items')
          .select('id,title,content_type,slug,body,caption,byline,source_note,cover_media_path,tags,published_at,created_at')
          .order('published_at', ascending: false, nullsFirst: false);
      if (!mounted) return;
      final normalized = List<Map<String, dynamic>>.from(rows).map((row) {
        final copy = Map<String, dynamic>.from(row);
        copy['_ui_status'] = copy['published_at'] != null ? 'published' : 'draft';
        return copy;
      }).toList();
      setState(() { _items = normalized; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publishing workspace could not load: ' + e.toString())));
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (_) => _PublishingEditor(item: item),
    );
    if (saved == true) _load();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items.where((x) {
      final status = x['_ui_status']?.toString() ?? '';
      final title = x['title']?.toString().toLowerCase() ?? '';
      return (_filter == 'all' || status == _filter) && (q.isEmpty || title.contains(q));
    }).toList();
  }

  @override Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: NileAppBar(title: 'Publishing Studio', actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.edit_outlined), label: const Text('New story'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(NileSpacing.md), children: [
          Text('Newsroom & social publishing', style: NileTypography.headlineSmall),
          const SizedBox(height: 6),
          Text('Write once, prepare channel-specific media and copy, submit for review, schedule and keep an accountable publication record.', style: NileTypography.bodyMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () => context.push('/admin/cms/publishing/calendar'), icon: const Icon(Icons.calendar_month_outlined), label: const Text('Editorial calendar')),
            OutlinedButton.icon(onPressed: () => context.go('/admin/cms/media'), icon: const Icon(Icons.perm_media_outlined), label: const Text('Media library')),
          ]),
          const SizedBox(height: NileSpacing.md),
          TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search stories, releases and posts…')),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['all','draft','in_review','approved','scheduled','published','archived'].map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(s == 'all' ? 'All' : s.replaceAll('_',' ')), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
            )).toList()),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && visible.isEmpty) const NileCard(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No publishing items yet.')))),
          ...visible.map(_itemCard),
        ]),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) => NileCard(
    margin: const EdgeInsets.only(bottom: 10),
    onTap: () => _openEditor(item),
    child: Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: NileColors.primaryContainer, borderRadius: NileRadius.borderMd),
        child: Icon(_iconFor(item['content_type']?.toString()), color: NileColors.primary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['title']?.toString() ?? 'Untitled', style: NileTypography.titleMedium),
        Text((item['content_type']?.toString() ?? 'content') + ' · ' + (item['byline']?.toString() ?? 'No byline'), style: NileTypography.bodySmall),
        if (item['scheduled_at'] != null) Text('Scheduled: ' + item['scheduled_at'].toString(), style: NileTypography.bodySmall),
      ])),
      _StatusPill(item['_ui_status']?.toString() ?? 'draft'),
      const Icon(Icons.chevron_right, color: NileColors.textTertiary),
    ]),
  );

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
  static const channels = ['website','facebook','instagram','linkedin','x','youtube','whatsapp','newsletter','press'];
  late final TextEditingController _title, _body, _caption, _byline, _tags, _source, _slug, _reviewNote;
  String _type = 'social_post';
  String _status = 'draft';
  final Set<String> _selectedChannels = {'website','facebook','instagram'};
  final Set<String> _mediaPaths = {};
  final Map<String, TextEditingController> _channelCopies = {};
  String? _coverPath;
  DateTime? _scheduledAt;
  DateTime? _embargoUntil;
  DateTime? _publishedAt;
  bool _saving = false;
  bool _loading = true;
  bool _canReview = false;
  bool _canEdit = false;
  List<Map<String, dynamic>> _events = [];

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
    _reviewNote = TextEditingController();
    _scheduledAt = DateTime.tryParse(x?['scheduled_at']?.toString() ?? '');
    _embargoUntil = DateTime.tryParse(x?['embargo_until']?.toString() ?? '');
    _status = x?['status']?.toString() ?? 'draft';
    for (final c in channels) _channelCopies[c] = TextEditingController();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final roles = await AuthService.rolesForCurrentUser();
      final manager = roles.contains('manager') || roles.contains('super_admin');
      _canReview = manager;
      _canEdit = manager || roles.contains('journalist') || roles.contains('content_manager');
      if (widget.item != null) {
        final id = widget.item!['id'].toString();
        final item = await SupabaseService.client.from('publishing_items')
          .select('title,body,caption,byline,tags,slug,source_note,cover_media_path,published_at,content_type')
          .eq('id', id).single();
        final targets = await SupabaseService.client.from('publishing_targets')
          .select('channel,copy,media_paths').eq('item_id', id).order('channel');
        final events = await SupabaseService.client.from('publishing_item_events')
          .select('event_type,from_status,to_status,note,created_at').eq('item_id', id)
          .order('created_at', ascending: false).limit(50);
        _title.text = item['title']?.toString() ?? '';
        _body.text = item['body']?.toString() ?? '';
        _caption.text = item['caption']?.toString() ?? '';
        _byline.text = item['byline']?.toString() ?? '';
        _tags.text = item['tags'] is List ? (item['tags'] as List).join(', ') : '';
        _reviewNote.clear();
        _source.text = item['source_note']?.toString() ?? '';
        _slug.text = item['slug']?.toString() ?? '';
        _coverPath = item['cover_media_path']?.toString();
        _scheduledAt = null;
        _embargoUntil = null;
        _publishedAt = DateTime.tryParse(item['published_at']?.toString() ?? '');
        _status = item['published_at'] != null ? 'published' : 'draft';
        _type = item['content_type']?.toString() ?? 'social_post';
        for (final row in List<Map<String,dynamic>>.from(targets)) {
          final c = row['channel']?.toString();
          if (c == null || !channels.contains(c)) continue;
          _selectedChannels.add(c);
          _channelCopies[c]!.text = row['copy']?.toString() ?? '';
          final media = row['media_paths'];
          if (media is List) _mediaPaths.addAll(media.map((e) => e.toString()));
        }
        _events = List<Map<String,dynamic>>.from(events);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _canEdit = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publishing item could not be opened: ' + e.toString())));
      }
    }
  }

  @override void dispose() {
    _title.dispose(); _body.dispose(); _caption.dispose(); _byline.dispose(); _tags.dispose(); _source.dispose(); _slug.dispose(); _reviewNote.dispose();
    for (final c in _channelCopies.values) c.dispose();
    super.dispose();
  }

  Future<void> _runAi(String action) async {
    if (!_canEdit || _saving) return;
    try {
      final ai = await PublishingAiService.assist(
        action: action,
        channel: _selectedChannels.isEmpty ? 'website' : _selectedChannels.first,
        itemId: widget.item?['id']?.toString(),
        article: {
          'title': _title.text.trim(), 'body': _body.text.trim(), 'caption': _caption.text.trim(),
          'byline': _byline.text.trim(), 'source_note': _source.text.trim(), 'slug': _slug.text.trim(),
          'tags': _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          'content_type': _type,
        },
        source: _source.text.trim(),
      );
      if (mounted) await _showAiResult(action, ai);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI assistance failed: ${e.toString()}')));
    }
  }

  Future<void> _showAiResult(String action, PublishingAiResult ai) async {
    final r = ai.result;
    final flags = (r['fact_flags'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final preview = [
      if ((r['title']?.toString() ?? '').isNotEmpty) 'Headline: ${r['title']}',
      if ((r['body']?.toString() ?? '').isNotEmpty) 'Draft:\n${r['body']}',
      if ((r['caption']?.toString() ?? '').isNotEmpty) 'Caption:\n${r['caption']}',
      if ((r['meta_description']?.toString() ?? '').isNotEmpty) 'Meta description: ${r['meta_description']}',
      if ((r['slug']?.toString() ?? '').isNotEmpty) 'Slug: ${r['slug']}',
      if ((r['tags'] as List?)?.isNotEmpty ?? false) 'Tags: ${(r['tags'] as List).join(', ')}',
      if ((r['social_copy']?.toString() ?? '').isNotEmpty) 'Social copy:\n${r['social_copy']}',
    ].join('\n\n');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('AI ${action.replaceAll('_', ' ')}'),
        content: SizedBox(width: 760, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Model: ${ai.model}', style: NileTypography.bodySmall),
          const SizedBox(height: 12), SelectableText(preview),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 16), Text('Needs verification', style: NileTypography.titleSmall),
            ...flags.map((x) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.warning_amber_outlined), title: Text(x))),
          ],
          const SizedBox(height: 12), Text('AI never publishes automatically. Review before accepting.', style: NileTypography.bodySmall),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Discard')),
          FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.check), label: const Text('Accept into editor')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      if ((r['title']?.toString() ?? '').isNotEmpty) _title.text = r['title'].toString();
      if (action != 'seo' && (r['body']?.toString() ?? '').isNotEmpty) _body.text = r['body'].toString();
      if ((r['caption']?.toString() ?? '').isNotEmpty) _caption.text = r['caption'].toString();
      if ((r['slug']?.toString() ?? '').isNotEmpty) _slug.text = r['slug'].toString();
      final tags = r['tags']; if (tags is List && tags.isNotEmpty) _tags.text = tags.map((e) => e.toString()).join(', ');
      final social = r['social_copy']?.toString() ?? '';
      if (social.isNotEmpty) _channelCopies[_selectedChannels.isEmpty ? 'website' : _selectedChannels.first]?.text = social;
    });
  }

  Future<void> _openAiMenu() async {
    if (!_canEdit) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(child: Wrap(children: [
        const ListTile(title: Text('AI editorial assistant'), subtitle: Text('AI proposes text; you review and accept it.')),
        ListTile(leading: const Icon(Icons.edit_note), title: const Text('Draft article'), onTap: () => Navigator.pop(context, 'draft')),
        ListTile(leading: const Icon(Icons.auto_fix_high), title: const Text('Improve writing'), onTap: () => Navigator.pop(context, 'improve')),
        ListTile(leading: const Icon(Icons.compress), title: const Text('Shorten'), onTap: () => Navigator.pop(context, 'shorten')),
        ListTile(leading: const Icon(Icons.expand), title: const Text('Expand'), onTap: () => Navigator.pop(context, 'expand')),
        ListTile(leading: const Icon(Icons.search), title: const Text('SEO suggestions'), onTap: () => Navigator.pop(context, 'seo')),
        ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Create social copy'), onTap: () => Navigator.pop(context, 'social')),
        ListTile(leading: const Icon(Icons.fact_check_outlined), title: const Text('Check unsupported claims'), onTap: () => Navigator.pop(context, 'fact_check')),
      ])),
    );
    if (action != null) await _runAi(action);
  }

  Future<void> _pickMedia({required bool cover}) async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MediaPickerDialog(initial: cover ? (_coverPath == null ? <String>{} : {_coverPath!}) : _mediaPaths, single: cover),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (cover) _coverPath = picked.isEmpty ? null : picked.first;
      else { _mediaPaths..clear()..addAll(picked); }
    });
  }

  Future<void> _chooseDate({required bool embargo}) async {
    final now = DateTime.now();
    final current = embargo ? _embargoUntil : _scheduledAt;
    final initial = current != null && current.isAfter(now) ? current : now;
    final date = await showDatePicker(context: context, firstDate: now.subtract(const Duration(minutes:1)), lastDate: now.add(const Duration(days:730)), initialDate: initial);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final value = DateTime(date.year,date.month,date.day,time.hour,time.minute);
    setState(() { if (embargo) _embargoUntil = value; else _scheduledAt = value; });
  }

  Future<void> _editChannelCopy(String channel) async {
    final copy = TextEditingController(text: _channelCopies[channel]!.text);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(channel.toUpperCase() + ' version'),
      content: SizedBox(width:620,child:TextField(controller:copy,minLines:8,maxLines:14,decoration:const InputDecoration(labelText:'Channel-specific copy'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Save version'))],
    ));
    if (ok == true && mounted) { _channelCopies[channel]!.text = copy.text; setState(() {}); }
    copy.dispose();
  }

  Future<void> _showAudit() async {
    if (widget.item == null) return;
    final rows = await SupabaseService.client.from('publishing_item_events')
      .select('event_type,from_status,to_status,note,created_at').eq('item_id', widget.item!['id'].toString())
      .order('created_at', ascending: false).limit(50);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (_) => AlertDialog(
      title: const Text('Editorial history'),
      content: SizedBox(width:650,height:430,child:rows.isEmpty ? const Center(child:Text('No history recorded yet.')) : ListView.separated(
        itemCount: rows.length, separatorBuilder:(_,__)=>const Divider(),
        itemBuilder:(_,i) {
          final e = rows[i] as Map<String,dynamic>;
          final detail = [e['from_status'],e['to_status'],e['note']].where((v)=>v!=null && v.toString().isNotEmpty).join(' → ');
          return ListTile(
            dense:true, leading:const Icon(Icons.history),
            title:Text((e['event_type']?.toString() ?? 'event').replaceAll('_',' ')),
            subtitle:Text(detail),
            trailing:Text((e['created_at']?.toString() ?? '').replaceFirst('T',' ').split('.').first),
          );
        },
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))],
    ));
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Headline / working title is required.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Match the live production publishing_items schema. Published
      // articles are editable rows; obsolete workflow columns are not sent.
      final payload = <String, dynamic>{
        'title': _title.text.trim(),
        'slug': _slug.text.trim().isEmpty ? null : _slug.text.trim(),
        'content_type': _type,
        'body': _body.text.trim(),
        'caption': _caption.text.trim(),
        'byline': _byline.text.trim(),
        'source_note': _source.text.trim(),
        'cover_media_path': _coverPath,
        'tags': _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'published_at': _status == 'published'
            ? (_publishedAt ?? DateTime.now().toUtc()).toUtc().toIso8601String()
            : null,
      };

      String id;
      if (widget.item == null) {
        final created = await SupabaseService.client
            .from('publishing_items')
            .insert(payload)
            .select('id')
            .single();
        id = created['id'].toString();
      } else {
        id = widget.item!['id'].toString();
        await SupabaseService.client.from('publishing_items').update(payload).eq('id', id);
      }

      // Keep an existing website target in sync when present. A target-sync
      // failure must never prevent the article itself from being saved.
      try {
        await SupabaseService.client
            .from('publishing_targets')
            .update({
              'headline': _title.text.trim(),
              'copy': _channelCopies['website']!.text.trim().isEmpty
                  ? _caption.text.trim()
                  : _channelCopies['website']!.text.trim(),
              'media_paths': _mediaPaths.toList(),
            })
            .eq('item_id', id)
            .eq('channel', 'website');
      } catch (_) {}

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save article: ' + e.toString())),
        );
      }
    }
  }

  Future<void> _changeWorkflowStatus(String next) async {
    if (!_canEdit) return;
    setState(() {
      _status = next;
      if (next == 'published') {
        _selectedChannels.add('website');
        _publishedAt ??= DateTime.now().toUtc();
      }
    });
    await _save();
  }

  Future<void> _publishToWebsite() async {
    if (!_canEdit) return;
    await _changeWorkflowStatus('published');
  }

  Future<void> _openPublishedWebsite() async {
    final id = widget.item?['id']?.toString();
    if (id == null || id.isEmpty) return;
    final slug = _slug.text.trim();
    final uri = Uri.https('niletropicaluganda.com', '/articles.html', {
      'id': id,
      if (slug.isNotEmpty) 'slug': slug,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<String> get _allowedStatuses => _canReview ? const ['draft','in_review','approved','scheduled','published','archived'] : const ['draft','in_review'];

  @override Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          width: 560,
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final editorChildren = <Widget>[
      TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: 'Headline / working title'),
      ),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _canEdit ? _openAiMenu : null, icon: const Icon(Icons.auto_awesome), label: const Text('AI writing assistant'))),
      const SizedBox(height: 10),
      TextField(
        controller: _slug,
        decoration: const InputDecoration(labelText: 'Slug'),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _type,
        decoration: const InputDecoration(labelText: 'Content type'),
        items: const [
          DropdownMenuItem(value: 'social_post', child: Text('Social media post')),
          DropdownMenuItem(value: 'news_story', child: Text('News story')),
          DropdownMenuItem(value: 'press_release', child: Text('Press release')),
          DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
          DropdownMenuItem(value: 'photo_story', child: Text('Photo story')),
          DropdownMenuItem(value: 'video_story', child: Text('Video story')),
        ],
        onChanged: _canEdit ? (v) => setState(() => _type = v!) : null,
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _byline,
        decoration: const InputDecoration(labelText: 'Byline / journalist'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _source,
        decoration: const InputDecoration(labelText: 'Source / attribution note'),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _canEdit ? () => _pickMedia(cover: true) : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _coverPath == null
                    ? 'Choose cover media'
                    : 'Cover: ' + _coverPath!.split('/').last,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _canEdit ? () => _pickMedia(cover: false) : null,
              icon: const Icon(Icons.perm_media_outlined),
              label: Text(
                _mediaPaths.isEmpty
                    ? 'Choose story media'
                    : _mediaPaths.length.toString() + ' media selected',
              ),
            ),
          ),
        ],
      ),
    ];

    if (_mediaPaths.isNotEmpty) {
      editorChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _mediaPaths.map((p) => p.split('/').last).join(' · '),
            style: NileTypography.bodySmall,
          ),
        ),
      );
    }

    editorChildren.addAll([
      const SizedBox(height: 10),
      TextField(
        controller: _caption,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Social caption / standfirst'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _body,
        minLines: 8,
        maxLines: 16,
        decoration: const InputDecoration(labelText: 'Story / editorial copy'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _tags,
        decoration: const InputDecoration(
          labelText: 'Tags',
          hintText: 'uganda, shea, community',
        ),
      ),
      const SizedBox(height: 14),
      Text('Channel publishing plan', style: NileTypography.titleSmall),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: channels.map((c) {
          return FilterChip(
            label: Text(c),
            selected: _selectedChannels.contains(c),
            onSelected: _canEdit
                ? (v) => setState(() {
                      if (v) {
                        _selectedChannels.add(c);
                      } else {
                        _selectedChannels.remove(c);
                      }
                    })
                : null,
          );
        }).toList(),
      ),
      const SizedBox(height: 8),
    ]);

    for (final c in _selectedChannels) {
      editorChildren.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: _canEdit ? () => _editChannelCopy(c) : null,
            icon: const Icon(Icons.tune_outlined),
            label: Text(
              c.toUpperCase() +
                  ' copy' +
                  (_channelCopies[c]!.text.trim().isEmpty ? '' : ' ✓'),
            ),
          ),
        ),
      );
    }

    editorChildren.addAll([
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NileColors.primaryContainer,
          borderRadius: NileRadius.borderMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _status == 'published' ? Icons.public : Icons.edit_note_outlined,
              color: NileColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _status == 'published'
                    ? 'Published article — title and all editorial fields remain editable. Save changes to update the live article. The original publication time is preserved.'
                    : 'Draft article — edit the content and save when ready.',
                style: NileTypography.bodySmall,
              ),
            ),
          ],
        ),
      ),
);

    if (_events.isNotEmpty) {
      editorChildren.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _events.length.toString() + ' audit events recorded',
            style: NileTypography.bodySmall,
          ),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.item == null ? 'New publishing item' : 'Edit publishing item',
            ),
          ),
          if (widget.item != null)
            IconButton(
              onPressed: _showAudit,
              tooltip: 'Editorial history',
              icon: const Icon(Icons.history),
            ),
        ],
      ),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: editorChildren,
          ),
        ),
      ),
      actions: [
        if (widget.item != null && _status == 'published')
          TextButton.icon(
            onPressed: _saving ? null : _openPublishedWebsite,
            icon: const Icon(Icons.public),
            label: const Text('Open website'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _saving || !_canEdit ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
,
    );
  }}

class _MediaPickerDialog extends StatefulWidget {
  const _MediaPickerDialog({required this.initial, required this.single});
  final Set<String> initial;
  final bool single;
  @override State<_MediaPickerDialog> createState()=>_MediaPickerDialogState();
}

class _MediaPickerDialogState extends State<_MediaPickerDialog> {
  static const folders = ['website','banners','testimonials','videos'];
  String _folder = 'website';
  bool _loading = true;
  final Set<String> _selected = {};
  List<dynamic> _files = const [];

  @override void initState(){super.initState();_selected.addAll(widget.initial);_load();}
  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final files=await StorageService.list(bucket:StorageService.cms,path:_folder);
      if(mounted)setState(()=>_files=files.where((f)=>f.name!='.emptyFolderPlaceholder').toList());
    } finally { if(mounted)setState(()=>_loading=false); }
  }
  void _toggle(String path) {
    setState(() {
      if (widget.single) { _selected..clear()..add(path); }
      else if (_selected.contains(path)) _selected.remove(path); else _selected.add(path);
    });
  }
  @override Widget build(BuildContext context)=>AlertDialog(
    title:Text(widget.single?'Choose cover media':'Choose story media'),
    content:SizedBox(width:820,height:520,child:Column(children:[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: folders.map((f) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f),
                selected: _folder == f,
                onSelected: (_) {
                  setState(() => _folder = f);
                  _load();
                },
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height:10),if(_loading)const LinearProgressIndicator(),
      Expanded(child:_files.isEmpty&&!_loading?const Center(child:Text('No media in this folder.')):GridView.builder(
        gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:230,mainAxisExtent:92,crossAxisSpacing:8,mainAxisSpacing:8),
        itemCount:_files.length,itemBuilder:(_,i){
          final name=_files[i].name?.toString()??''; final path=_folder+'/'+name; final selected=_selected.contains(path);
          return InkWell(onTap:()=>_toggle(path),child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(border:Border.all(color:selected?NileColors.primary:NileColors.border),borderRadius:BorderRadius.circular(10),color:selected?NileColors.primaryContainer:null),child:Row(children:[Icon(selected?Icons.check_circle:Icons.insert_drive_file_outlined,color:NileColors.primary),const SizedBox(width:8),Expanded(child:Text(name,maxLines:3,overflow:TextOverflow.ellipsis))])));
        },
      )),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(context,_selected.toList()),icon:const Icon(Icons.check),label:Text('Use '+_selected.length.toString()))],
  );
}
