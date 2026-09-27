import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/image_quality_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';
import '../widgets/admin_image_frame.dart';

class CmsAppHeroSlotsScreen extends StatefulWidget {
  const CmsAppHeroSlotsScreen({super.key});
  @override
  State<CmsAppHeroSlotsScreen> createState() => _CmsAppHeroSlotsScreenState();
}

class _CmsAppHeroSlotsScreenState extends State<CmsAppHeroSlotsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _slots = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseService.client
          .from('website_media_slots')
          .select('slot_key,label,storage_path,alt_text,is_active,updated_at')
          .like('slot_key', 'app_hero_%')
          .order('slot_key');
      if (!mounted) return;
      setState(() { _slots = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load Store App HERO slots: $e')));
    }
  }

  String _url(String? path) => StorageService.resolvePublicUrl(path, bucket: StorageService.cms);

  Future<void> _upload(Map<String, dynamic> slot) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final quality = await ImageQualityService.inspect(bytes: bytes, folder: 'website');
      if (!quality.passes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image rejected: ' + quality.dimensions + ' (' + quality.sizeLabel + '). Minimum ' +
              quality.minWidth.toString() + ' × ' + quality.minHeight.toString() + 'px.'),
          backgroundColor: NileColors.error,
        ));
        return;
      }
      final safe = picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-').replaceAll(RegExp(r'-+'), '-');
      final path = 'app/' + slot['slot_key'].toString() + '-' +
          DateTime.now().microsecondsSinceEpoch.toString() + '-' + safe;
      await StorageService.upload(
        bucket: StorageService.cms, objectPath: path, bytes: bytes,
        contentType: picked.mimeType ?? 'image/jpeg',
      );
      await SupabaseService.client.from('website_media_slots').update({
        'storage_path': path, 'is_active': true,
        'updated_by': SupabaseService.client.auth.currentUser?.id,
      }).eq('slot_key', slot['slot_key']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(slot['label'].toString() + ' replaced successfully.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload image: $e'), backgroundColor: NileColors.error),
      );
    }
  }

  Future<void> _editAlt(Map<String, dynamic> slot) async {
    final controller = TextEditingController(text: slot['alt_text']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ' + slot['label'].toString()),
        content: TextField(
          controller: controller, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Image description (alt text)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await SupabaseService.client.from('website_media_slots').update({
      'alt_text': value.isEmpty ? null : value,
      'updated_by': SupabaseService.client.auth.currentUser?.id,
    }).eq('slot_key', slot['slot_key']);
    await _load();
  }

  Future<void> _clear(Map<String, dynamic> slot) async {
    await SupabaseService.client.from('website_media_slots').update({
      'storage_path': null, 'is_active': true,
      'updated_by': SupabaseService.client.auth.currentUser?.id,
    }).eq('slot_key', slot['slot_key']);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store App HERO')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Store App HOME slider', style: NileTypography.headlineSmall),
            const SizedBox(height: 6),
            Text('Replace the four images used by the shopping app. Changes affect /app/ only; the public website HERO is separate.',
              style: NileTypography.bodyMedium),
            const SizedBox(height: 16),
            ..._slots.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> slot) {
    final path = slot['storage_path']?.toString();
    final active = path != null && path.isNotEmpty && slot['is_active'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 700;
          final image = SizedBox(
            width: compact ? double.infinity : 190,
            height: compact ? 180 : 115,
            child: active
                ? AdminImageFrame(url: _url(path), fit: BoxFit.cover, expand: true, borderRadius: 10, label: 'Store App HERO')
                : const Center(child: Icon(Icons.image_outlined, size: 42)),
          );
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot['label']?.toString() ?? '', style: NileTypography.titleMedium),
              const SizedBox(height: 6),
              Text(active ? path! : 'Using bundled app fallback image.', style: NileTypography.bodySmall),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(onPressed: () => _upload(slot), icon: const Icon(Icons.upload_outlined), label: Text(active ? 'Upload & replace' : 'Upload image')),
                OutlinedButton.icon(onPressed: () => _editAlt(slot), icon: const Icon(Icons.edit_outlined), label: const Text('Edit details')),
                if (active) TextButton.icon(onPressed: () => _clear(slot), icon: const Icon(Icons.restore_outlined), label: const Text('Use app fallback')),
              ]),
            ],
          );
          return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [image, const SizedBox(height: 12), info])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [image, const SizedBox(width: 16), Expanded(child: info)]);
        }),
      ),
    );
  }
}
