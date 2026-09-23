import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/media_upload.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';

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
                      final path = await MediaUpload.pickAndUpload(
                        bucket: StorageService.cms,
                        objectPath: 'banners/${DateTime.now().millisecondsSinceEpoch}.jpg',
                        source: ImageSource.gallery,
                      );
                      if (path != null) setDialogState(() => imagePath = path);
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

    if (result != true || imagePath == null) return;

    try {
      await SupabaseService.client.from('banners').insert({
        'title': title.text.trim().isEmpty ? null : title.text.trim(),
        'image_storage_path': imagePath,
        'link_url': link.text.trim().isEmpty ? null : link.text.trim(),
        'sort_order': int.tryParse(sort.text) ?? 0,
        'is_active': active,
      });
      title.dispose();
      link.dispose();
      sort.dispose();
      await _load();
    } catch (e) {
      title.dispose();
      link.dispose();
      sort.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create banner: $e'), backgroundColor: NileColors.error),
      );
    }
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
