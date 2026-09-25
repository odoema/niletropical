import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/cms_media_upload.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';
import 'package:intl/intl.dart';

class CmsBannersScreen extends StatefulWidget {
  const CmsBannersScreen({super.key});

  @override
  State<CmsBannersScreen> createState() => _CmsBannersScreenState();
}

class _CmsBannersScreenState extends State<CmsBannersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.client
          .from('banners')
          .select()
          .order('sort_order')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load banners: $e'), backgroundColor: NileColors.error),
      );
    }
  }

  Future<void> _createBanner() async {
    final title = TextEditingController();
    final link = TextEditingController();
    final sort = TextEditingController(text: '0');
    final starts = TextEditingController();
    final ends = TextEditingController();
    bool active = true;
    String? imagePath;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add website banner'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  TextField(controller: link, decoration: const InputDecoration(labelText: 'Link URL (optional)')),
                  const SizedBox(height: 12),
                  TextField(controller: sort, decoration: const InputDecoration(labelText: 'Display order'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: starts, decoration: const InputDecoration(labelText: 'Starts (YYYY-MM-DD HH:MM, optional)')),
                  const SizedBox(height: 12),
                  TextField(controller: ends, decoration: const InputDecoration(labelText: 'Ends (YYYY-MM-DD HH:MM, optional)')),
                  const SizedBox(height: 16),
                  if (imagePath != null)
                    Container(
                      height: 160,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                      child: Image.network(
                        StorageService.resolvePublicUrl(imagePath, bucket: StorageService.cms),
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await CmsMediaUpload.pickAndUpload(
                        context: ctx,
                        folder: 'banners',
                        objectPrefix: 'banner',
                      );
                      if (result != null) {
                        setDialogState(() => imagePath = result.path);
                      }
                    },
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload banner image'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active on storefront'),
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: imagePath == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Create banner'),
            ),
          ],
        ),
      ),
    );

    if (result != true || imagePath == null) {
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
      return;
    }

    DateTime? parseDate(String value) =>
        value.trim().isEmpty ? null : DateTime.tryParse(value.trim());
    final startDate = parseDate(starts.text);
    final endDate = parseDate(ends.text);
    if ((starts.text.trim().isNotEmpty && startDate == null) ||
        (ends.text.trim().isNotEmpty && endDate == null) ||
        (startDate != null && endDate != null && !endDate.isAfter(startDate))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use valid dates and make sure the end is after the start.'), backgroundColor: NileColors.error),
      );
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
      return;
    }
    final linkValue = link.text.trim();
    final parsedLink = Uri.tryParse(linkValue);
    final validLink = linkValue.isEmpty || linkValue.startsWith('/') || (parsedLink != null && (parsedLink.scheme == 'http' || parsedLink.scheme == 'https') && parsedLink.host.isNotEmpty);
    if (!validLink) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link URL must be a full URL or an app route beginning with /.'), backgroundColor: NileColors.error),
      );
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
      return;
    }

    try {
      await SupabaseService.client.from('banners').insert({
        'title': title.text.trim().isEmpty ? null : title.text.trim(),
        'image_storage_path': imagePath,
        'link_url': link.text.trim().isEmpty ? null : link.text.trim(),
        'sort_order': int.tryParse(sort.text) ?? 0,
        'is_active': active,
        'starts_at': startDate?.toUtc().toIso8601String(),
        'ends_at': endDate?.toUtc().toIso8601String(),
      });
      title.dispose();
      link.dispose();
      sort.dispose();
      starts.dispose();
      ends.dispose();
      await _load();
    } catch (e) {
      title.dispose();
      link.dispose();
      sort.dispose();
      starts.dispose();
      ends.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create banner: $e'), backgroundColor: NileColors.error),
      );
    }
  }


  Future<void> _edit(Map<String, dynamic> row) async {
    final title = TextEditingController(text: row['title']?.toString() ?? '');
    final link = TextEditingController(text: row['link_url']?.toString() ?? '');
    final sort = TextEditingController(text: row['sort_order']?.toString() ?? '0');
    final starts = TextEditingController(text: _dateValue(row['starts_at']));
    final ends = TextEditingController(text: _dateValue(row['ends_at']));
    bool active = row['is_active'] == true;
    String? imagePath = row['image_storage_path']?.toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit banner'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  TextField(controller: link, decoration: const InputDecoration(labelText: 'Link URL (optional)')),
                  const SizedBox(height: 12),
                  TextField(controller: sort, decoration: const InputDecoration(labelText: 'Display order'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: starts, decoration: const InputDecoration(labelText: 'Starts (YYYY-MM-DD HH:MM, optional)')),
                  const SizedBox(height: 12),
                  TextField(controller: ends, decoration: const InputDecoration(labelText: 'Ends (YYYY-MM-DD HH:MM, optional)')),
                  const SizedBox(height: 12),
                  if (imagePath != null)
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(
                        StorageService.resolvePublicUrl(imagePath, bucket: StorageService.cms),
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await CmsMediaUpload.pickAndUpload(
                        context: ctx,
                        folder: 'banners',
                        objectPrefix: 'banner',
                      );
                      if (result != null) {
                        setDialogState(() => imagePath = result.path);
                      }
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Replace image'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active on storefront'),
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: imagePath == null ? null : () => Navigator.pop(ctx, true), child: const Text('Save changes')),
          ],
        ),
      ),
    );

    if (result != true || imagePath == null) {
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
      return;
    }

    DateTime? parseDate(String value) =>
        value.trim().isEmpty ? null : DateTime.tryParse(value.trim());
    final startDate = parseDate(starts.text);
    final endDate = parseDate(ends.text);
    if ((starts.text.trim().isNotEmpty && startDate == null) ||
        (ends.text.trim().isNotEmpty && endDate == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use YYYY-MM-DD HH:MM for banner dates.'), backgroundColor: NileColors.error),
        );
      }
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
      return;
    }
    if (startDate != null && endDate != null && !endDate.isAfter(startDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.'), backgroundColor: NileColors.error),
        );
      }
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
      return;
    }

    try {
      await SupabaseService.client.from('banners').update({
        'title': title.text.trim().isEmpty ? null : title.text.trim(),
        'image_storage_path': imagePath,
        'link_url': link.text.trim().isEmpty ? null : link.text.trim(),
        'sort_order': int.tryParse(sort.text) ?? 0,
        'is_active': active,
        'starts_at': startDate?.toUtc().toIso8601String(),
        'ends_at': endDate?.toUtc().toIso8601String(),
      }).eq('id', row['id']);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update banner: ' + e.toString()), backgroundColor: NileColors.error),
        );
      }
    } finally {
      title.dispose(); link.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
    }
  }

  String _dateValue(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    return date == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    try {
      await SupabaseService.client
          .from('banners')
          .update({'is_active': !(row['is_active'] == true)})
          .eq('id', row['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update banner: $e'), backgroundColor: NileColors.error),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete banner?'),
        content: const Text('The banner record will be deleted. The uploaded media can then be removed from the Media Library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: NileColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client.from('banners').delete().eq('id', row['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: NileColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Website Banners'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _createBanner,
            icon: const Icon(Icons.add),
            label: const Text('Add banner'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('No banners yet. Add your first website banner.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final row = _rows[i];
                    final path = row['image_storage_path']?.toString();
                    final url = StorageService.resolvePublicUrl(path, bucket: StorageService.cms);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 230,
                            height: 130,
                            child: url.isEmpty
                                ? const Center(child: Icon(Icons.image_not_supported_outlined))
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row['title']?.toString() ?? 'Untitled banner', style: NileTypography.titleMedium),
                                  const SizedBox(height: 5),
                                  Text('Order: ${row['sort_order'] ?? 0}'),
                                  if (row['link_url'] != null) Text(row['link_url'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      FilterChip(
                                        selected: row['is_active'] == true,
                                        label: Text(row['is_active'] == true ? 'Active' : 'Inactive'),
                                        onSelected: (_) => _toggle(row),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _edit(row),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _delete(row),
                                        icon: const Icon(Icons.delete_outline, color: NileColors.error),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
