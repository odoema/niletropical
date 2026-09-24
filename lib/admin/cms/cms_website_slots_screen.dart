import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';

class CmsWebsiteSlotsScreen extends StatefulWidget {
  const CmsWebsiteSlotsScreen({super.key});

  @override
  State<CmsWebsiteSlotsScreen> createState() => _CmsWebsiteSlotsScreenState();
}

class _CmsWebsiteSlotsScreenState extends State<CmsWebsiteSlotsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _slots = [];
  List<dynamic> _files = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await SupabaseService.client
          .from('website_media_slots')
          .select('slot_key,label,storage_path,alt_text,is_active,updated_at')
          .order('slot_key');
      final files =
          await StorageService.list(bucket: StorageService.cms, path: 'website');
      if (!mounted) return;
      setState(() {
        _slots = List<Map<String, dynamic>>.from(slots);
        _files =
            files.where((f) => f.name != '.emptyFolderPlaceholder').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _url(String? path) =>
      StorageService.resolvePublicUrl(path, bucket: StorageService.cms);

  Future<void> _editDetails(Map<String, dynamic> slot) async {
    final controller =
        TextEditingController(text: slot['alt_text']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ' + slot['label'].toString()),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Image description (alt text)',
              helperText:
                  'Describe the image for accessibility and screen readers.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;

    try {
      await SupabaseService.client.from('website_media_slots').update({
        'alt_text': value.isEmpty ? null : value,
        'updated_by': SupabaseService.client.auth.currentUser?.id,
      }).eq('slot_key', slot['slot_key']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save image details: ' + e.toString()),
          backgroundColor: NileColors.error,
        ),
      );
    }
  }

  Future<void> _choose(Map<String, dynamic> slot) async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload website images in Media Library first.'),
        ),
      );
      return;
    }

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Choose image for ' + slot['label'].toString()),
        content: SizedBox(
          width: 720,
          height: 420,
          child: GridView.builder(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 170,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _files.length,
            itemBuilder: (_, i) {
              final file = _files[i];
              final name = file.name.toString();
              final path = 'website/' + name;
              return InkWell(
                onTap: () => Navigator.pop(ctx, path),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.network(
                          _url(path),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (picked == null) return;
    try {
      await SupabaseService.client.from('website_media_slots').update({
        'storage_path': picked,
        'is_active': true,
        'updated_by': SupabaseService.client.auth.currentUser?.id,
      }).eq('slot_key', slot['slot_key']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not assign image: ' + e.toString()),
          backgroundColor: NileColors.error,
        ),
      );
    }
  }

  Future<void> _clear(Map<String, dynamic> slot) async {
    try {
      await SupabaseService.client.from('website_media_slots').update({
        'storage_path': null,
        'is_active': false,
        'updated_by': SupabaseService.client.auth.currentUser?.id,
      }).eq('slot_key', slot['slot_key']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear slot: ' + e.toString()),
          backgroundColor: NileColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Website Slots'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/admin/cms/media'),
            icon: const Icon(Icons.perm_media_outlined),
            label: const Text('Media Library'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: NileColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load website slots.',
                          style: NileTypography.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _slots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final slot = _slots[i];
                      final path = slot['storage_path']?.toString();
                      final active = slot['is_active'] == true &&
                          path != null &&
                          path.isNotEmpty;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                height: 105,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: active
                                      ? Image.network(
                                          _url(path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: NileColors.surfaceVariant,
                                          child: const Icon(
                                            Icons.image_outlined,
                                            size: 38,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot['label']?.toString() ??
                                          slot['slot_key'].toString(),
                                      style: NileTypography.titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      active
                                          ? path!
                                          : 'Using the public website fallback image',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: NileTypography.bodySmall,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      slot['alt_text']?.toString().isNotEmpty ==
                                              true
                                          ? 'Alt: ' +
                                              slot['alt_text'].toString()
                                          : 'No alt text set',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: NileTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit image description',
                                    onPressed: () => _editDetails(slot),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _choose(slot),
                                    icon: const Icon(
                                        Icons.photo_library_outlined),
                                    label: Text(active ? 'Change' : 'Choose'),
                                  ),
                                  if (active)
                                    IconButton(
                                      tooltip: 'Use fallback image',
                                      onPressed: () => _clear(slot),
                                      icon: const Icon(Icons.clear),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
