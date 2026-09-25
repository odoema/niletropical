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

  Future<void> _confirmClear(Map<String, dynamic> slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use fallback image?'),
        content: Text(
          'This will remove the custom image from ' +
          slot['label'].toString() +
          ' and restore the public website fallback.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use fallback')),
        ],
      ),
    );
    if (ok == true) await _clear(slot);
  }

  Widget _slotCard(Map<String, dynamic> slot) {
    final path = slot['storage_path']?.toString();
    final active = slot['is_active'] == true && path != null && path.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final image = SizedBox(
              width: compact ? double.infinity : 190,
              height: compact ? 180 : 125,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: active
                    ? Image.network(
                        _url(path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: NileColors.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined, size: 34),
                        ),
                      )
                    : Container(
                        color: NileColors.surfaceVariant,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 38),
                      ),
              ),
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot['label']?.toString() ?? slot['slot_key'].toString(),
                  style: NileTypography.titleMedium,
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? NileColors.success.withValues(alpha: 0.10) : NileColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'Active' : 'Fallback',
                    style: NileTypography.bodySmall.copyWith(
                      color: active ? NileColors.success : NileColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  active ? path! : 'No custom image selected. The public website will use its fallback.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NileTypography.bodySmall,
                ),
                const SizedBox(height: 7),
                Text(
                  slot['alt_text']?.toString().isNotEmpty == true
                      ? 'Alt text: ' + slot['alt_text'].toString()
                      : 'Alt text: Not set',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NileTypography.bodySmall.copyWith(color: NileColors.textSecondary),
                ),
              ],
            );
            final actions = Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _choose(slot),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(active ? 'Change image' : 'Choose image'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editDetails(slot),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit details'),
                ),
                if (active)
                  TextButton.icon(
                    onPressed: () => _confirmClear(slot),
                    icon: const Icon(Icons.restore_outlined, size: 18),
                    label: const Text('Use fallback'),
                  ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [image, const SizedBox(height: 14), details, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                image,
                const SizedBox(width: 18),
                Expanded(child: details),
                const SizedBox(width: 20),
                SizedBox(width: 210, child: actions),
              ],
            );
          },
        ),
      ),
    );
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
            tooltip: 'Refresh website slots',
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
                        const Icon(Icons.error_outline, size: 48, color: NileColors.error),
                        const SizedBox(height: 12),
                        Text('Could not load website slots.', style: NileTypography.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          _error!.contains('PGRST205') || _error!.contains('website_media_slots')
                              ? 'The Website Slots database module has not been installed yet. Apply the website_media_slots migration to the Nile Tropical production Supabase project, then refresh this page.'
                              : _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth > 1000 ? 28.0 : constraints.maxWidth > 700 ? 20.0 : 12.0;
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
                        itemCount: _slots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _slotCard(_slots[i]),
                      );
                    },
                  ),
                ),
    );
  }
}
