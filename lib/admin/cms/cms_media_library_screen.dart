import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/services/image_quality_service.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';

class CmsMediaLibraryScreen extends StatefulWidget {
  const CmsMediaLibraryScreen({super.key});

  @override
  State<CmsMediaLibraryScreen> createState() => _CmsMediaLibraryScreenState();
}

class _CmsMediaLibraryScreenState extends State<CmsMediaLibraryScreen> {
  static const _folders = <String, String>{
    'website': 'Website images',
    'banners': 'Banners',
    'testimonials': 'Testimonials',
    'videos': 'CMS media',
  };

  String _folder = 'website';
  bool _loading = true;
  bool _uploading = false;
  List<dynamic> _files = const [];
  String? _error;

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
      final files = await StorageService.list(
        bucket: StorageService.cms,
        path: _folder,
      );
      if (!mounted) return;
      setState(() {
        _files = files.where((f) => f.name != '.emptyFolderPlaceholder').toList();
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

  Future<void> _upload() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final rejected = <String>[];

      for (var i = 0; i < picked.length; i++) {
        final file = picked[i];
        final bytes = await file.readAsBytes();
        final quality = await ImageQualityService.inspect(
          bytes: bytes,
          folder: _folder,
        );

        if (!quality.passes) {
          rejected.add(
            '${file.name}: ${quality.dimensions} (${quality.sizeLabel}). '
            'Minimum is ${quality.minWidth} × ${quality.minHeight}px.',
          );
          continue;
        }

        final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
        final safe = file.name
            .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-')
            .replaceAll(RegExp(r'-+'), '-');
        final path = '$_folder/${DateTime.now().millisecondsSinceEpoch}-$i-$safe';
        await StorageService.upload(
          bucket: StorageService.cms,
          objectPath: path,
          bytes: bytes,
          contentType: file.mimeType ?? 'image/$ext',
        );
      }
      if (!mounted) return;
      final uploaded = picked.length - rejected.length;
      if (!mounted) return;

      if (rejected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$uploaded media file${uploaded == 1 ? '' : 's'} uploaded')),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              uploaded == 0 ? 'Images not uploaded' : 'Some images were not uploaded',
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Text(
                  '${uploaded > 0 ? '$uploaded image${uploaded == 1 ? '' : 's'} uploaded successfully.\\n\\n' : ''}'
                  'These images are below the quality standard:\\n\\n'
                  '${rejected.join('\\n\\n')}',
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: NileColors.error),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(dynamic file) async {
    final name = file.name?.toString() ?? '';
    if (name.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete media?'),
        content: Text('This will permanently remove $name from the CMS media library.'),
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
      final path = '$_folder/$name';

      // Prevent deleting an image that is currently assigned to a live
      // website slot. This avoids silently breaking the public website.
      if (_folder == 'website') {
        final usedBy = await SupabaseService.client
            .from('website_media_slots')
            .select('label')
            .eq('storage_path', path);
        if ((usedBy as List).isNotEmpty) {
          final labels = usedBy
              .map((row) => row['label']?.toString())
              .whereType<String>()
              .join(', ');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This image is in use by: ' + labels + '. Change that slot first.',
              ),
              backgroundColor: NileColors.error,
            ),
          );
          return;
        }
      }

      await StorageService.delete(
        bucket: StorageService.cms,
        path: path,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: NileColors.error),
      );
    }
  }

  Future<void> _copyUrl(dynamic file) async {
    final name = file.name?.toString() ?? '';
    if (name.isEmpty) return;
    final url = StorageService.resolvePublicUrl(
      '$_folder/$name',
      bucket: StorageService.cms,
    );
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public image URL copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_uploading ? 'Uploading…' : 'Upload'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: NileColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: _folders.entries.map((entry) {
                  final selected = entry.key == _folder;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      label: Text(entry.value),
                      avatar: Icon(
                        entry.key == 'website'
                            ? Icons.language
                            : entry.key == 'banners'
                                ? Icons.view_carousel_outlined
                                : entry.key == 'testimonials'
                                    ? Icons.people_outline
                                    : Icons.perm_media_outlined,
                        size: 18,
                      ),
                      onSelected: (_) {
                        if (selected) return;
                        setState(() => _folder = entry.key);
                        _load();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Could not load media: $_error'))
                    : _files.isEmpty
                        ? _EmptyMedia(folder: _folders[_folder]!)
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisExtent: 290,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: _files.length,
                            itemBuilder: (_, i) {
                              final file = _files[i];
                              final name = file.name?.toString() ?? '';
                              final url = StorageService.resolvePublicUrl(
                                '$_folder/$name',
                                bucket: StorageService.cms,
                              );
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        color: NileColors.surfaceVariant,
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(child: Icon(Icons.broken_image_outlined, size: 44)),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                                      child: Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton.icon(
                                            onPressed: () => _copyUrl(file),
                                            icon: const Icon(Icons.link, size: 18),
                                            label: const Text('Copy URL'),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () => _delete(file),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedia extends StatelessWidget {
  const _EmptyMedia({required this.folder});
  final String folder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.perm_media_outlined, size: 64, color: NileColors.textTertiary),
              const SizedBox(height: 16),
              Text(folder, style: NileTypography.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Upload images here and reuse them across the Nile Tropical storefront and CMS.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                ImageQualityService.guidance(folder),
                textAlign: TextAlign.center,
                style: NileTypography.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
