import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/admin_image_frame.dart';

class ProductImageManagerScreen extends ConsumerStatefulWidget {
  const ProductImageManagerScreen({super.key});

  @override
  ConsumerState<ProductImageManagerScreen> createState() => _ProductImageManagerScreenState();
}

class _ProductImageManagerScreenState extends ConsumerState<ProductImageManagerScreen> {
  late Future<List<Map<String, dynamic>>> _products;
  final _picker = ImagePicker();
  String? _busyProductId;

  @override
  void initState() {
    super.initState();
    _products = _loadProducts();
  }

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    final rows = await SupabaseService.client
        .from('products')
        .select('id,name,slug,is_active,product_images(id,storage_path,is_main,sort_order,alt_text)')
        .isFilter('deleted_at', null)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  String _displayName(Map<String, dynamic> product) {
    final normalized = (product['name']?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? 'Unnamed product' : normalized;
  }

  String _slugFor(Map<String, dynamic> product) {
    final slug = (product['slug'] as String?)?.trim();
    return slug?.isNotEmpty == true ? slug! : product['id'].toString();
  }

  Future<void> _addImages(Map<String, dynamic> product) async {
    final productId = product['id'].toString();
    final picked = await _picker.pickMultiImage(imageQuality: 88);
    if (picked.isEmpty) return;

    setState(() => _busyProductId = productId);
    try {
      final existing = await SupabaseService.client.from('product_images').select('id,is_main').eq('product_id', productId);
      var hasMain = (existing as List).any((row) => (row as Map<String, dynamic>)['is_main'] == true);

      for (var i = 0; i < picked.length; i++) {
        final file = picked[i];
        final bytes = await file.readAsBytes();
        final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-').replaceAll(RegExp(r'-+'), '-');
        final path = 'products/${_slugFor(product)}/${DateTime.now().millisecondsSinceEpoch}-$i-$safeName';
        await StorageService.upload(bucket: StorageService.productImages, objectPath: path, bytes: bytes, contentType: file.mimeType ?? 'image/$ext');
        await SupabaseService.client.from('product_images').insert({
          'product_id': productId,
          'storage_path': path,
          'alt_text': _displayName(product),
          'sort_order': existing.length + i,
          'is_main': !hasMain && i == 0,
        });
        if (!hasMain && i == 0) hasMain = true;
      }
      if (!mounted) return;
      setState(() => _products = _loadProducts());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.length} image${picked.length == 1 ? '' : 's'} added to ${_displayName(product)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: NileColors.error));
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _setMain(String productId, String imageId) async {
    try {
      await SupabaseService.client.from('product_images').update({'is_main': false}).eq('product_id', productId);
      await SupabaseService.client.from('product_images').update({'is_main': true, 'sort_order': 0}).eq('id', imageId);
      if (!mounted) return;
      setState(() => _products = _loadProducts());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Main product image updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not set main image: $e'), backgroundColor: NileColors.error));
    }
  }

  Future<void> _deleteImage(String productId, Map<String, dynamic> image) async {
    final imageId = image['id']?.toString();
    final path = image['storage_path']?.toString();
    if (imageId == null || path == null || path.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product image?'),
        content: const Text('The image file and its catalogue reference will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: NileColors.error), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await StorageService.delete(bucket: StorageService.productImages, path: path);
      await SupabaseService.client.from('product_images').delete().eq('id', imageId);
      if (image['is_main'] == true) {
        final remaining = await SupabaseService.client.from('product_images').select('id').eq('product_id', productId).order('sort_order').limit(1);
        if ((remaining as List).isNotEmpty) {
          await SupabaseService.client.from('product_images').update({'is_main': true, 'sort_order': 0}).eq('id', remaining.first['id']);
        }
      }
      if (!mounted) return;
      setState(() => _products = _loadProducts());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: NileColors.error));
    }
  }

  Map<String, dynamic>? _mainImage(List<Map<String, dynamic>> images) {
    if (images.isEmpty) return null;
    final mains = images.where((image) => image['is_main'] == true).toList();
    if (mains.isNotEmpty) return mains.first;
    final sorted = [...images]
      ..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    return sorted.first;
  }

  Future<void> _showImageViewer(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> images,
    int initialIndex,
  ) async {
    if (images.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .88),
      builder: (dialogContext) {
        final controller = PageController(initialPage: initialIndex);
        var activeIndex = initialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 820),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: NileColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(blurRadius: 40, spreadRadius: 4)],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_displayName(product), style: NileTypography.titleLarge),
                                const SizedBox(height: 3),
                                Text(
                                  activeIndex.toString() + ' of ' + images.length.toString() + ' images',
                                  style: NileTypography.bodySmall.copyWith(color: NileColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close image viewer',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller: controller,
                            itemCount: images.length,
                            onPageChanged: (index) => setDialogState(() => activeIndex = index),
                            itemBuilder: (_, index) {
                              final url = StorageService.resolvePublicUrl(images[index]['storage_path']?.toString());
                              return Padding(
                                padding: const EdgeInsets.all(28),
                                child: InteractiveViewer(
                                  minScale: .8,
                                  maxScale: 4,
                                  child: AdminImageFrame(
                                    url: url,
                                    expand: true,
                                    fit: BoxFit.contain,
                                    borderRadius: 16,
                                    backgroundColor: NileColors.surfaceVariant,
                                    label: 'Product image',
                                  ),
                                ),
                              );
                            },
                          ),
                          if (images.length > 1)
                            Positioned(
                              left: 12,
                              child: IconButton.filled(
                                tooltip: 'Previous image',
                                onPressed: activeIndex == 0 ? null : () => controller.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
                                icon: const Icon(Icons.chevron_left),
                              ),
                            ),
                          if (images.length > 1)
                            Positioned(
                              right: 12,
                              child: IconButton.filled(
                                tooltip: 'Next image',
                                onPressed: activeIndex == images.length - 1 ? null : () => controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (images.length > 1)
                      SizedBox(
                        height: 86,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            final selected = index == activeIndex;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => controller.animateToPage(index, duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
                              child: Container(
                                width: 62,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? NileColors.primary : NileColors.border,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AdminImageFrame(
                                  url: StorageService.resolvePublicUrl(images[index]['storage_path']?.toString()),
                                  fit: BoxFit.cover,
                                  borderRadius: 9,
                                  backgroundColor: NileColors.surfaceVariant,
                                  label: 'Thumbnail',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showImageGallery(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> images,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayName(product),
                        style: NileTypography.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: images.length,
                    itemBuilder: (_, index) => _galleryImageTile(product, images, index),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _galleryImageTile(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> images,
    int index,
  ) {
    final image = images[index];
    final url = StorageService.resolvePublicUrl(image['storage_path']?.toString());
    final isMain = image['is_main'] == true;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showImageViewer(product, images, index),
        child: Stack(
          children: [
            AdminImageFrame(
          url: url,
          aspectRatio: 1,
          fit: BoxFit.contain,
          borderRadius: 12,
          backgroundColor: NileColors.surfaceVariant,
          label: 'Product image',
        ),
        if (isMain)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: NileColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'MAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        Positioned(
          right: 6,
          top: 6,
          child: IconButton(
            tooltip: 'Delete image',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .94),
              minimumSize: const Size(38, 38),
            ),
            onPressed: () => _deleteImage(product['id'].toString(), image),
            icon: const Icon(Icons.delete_outline, color: NileColors.error),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: isMain
              ? Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Text(
                      'Main image',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : FilledButton(
                  onPressed: () => _setMain(
                    product['id'].toString(),
                    image['id'].toString(),
                  ),
                  child: const Text('Set as main'),
                ),
        ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Image Manager',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        foregroundColor: Colors.white,
        backgroundColor: NileColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/products'),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load products: ${snapshot.error}'),
              ),
            );
          }

          final products = snapshot.data ?? const [];
          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _products = _loadProducts());
              await _products;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1450
                    ? 4
                    : constraints.maxWidth >= 980
                        ? 3
                        : constraints.maxWidth >= 620
                            ? 2
                            : 1;

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 405,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final images = (product['product_images'] as List?)
                            ?.map((x) => Map<String, dynamic>.from(x as Map))
                            .toList() ??
                        <Map<String, dynamic>>[];
                    final mainImage = _mainImage(images);
                    final busy = _busyProductId == product['id'];
                    final mainUrl = StorageService.resolvePublicUrl(
                      mainImage?['storage_path']?.toString(),
                    );

                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      elevation: 1,
                      shadowColor: Colors.black.withValues(alpha: .08),
                      surfaceTintColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayName(product),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Add product images',
                                  onPressed: busy ? null : () => _addImages(product),
                                  icon: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.add_photo_alternate_outlined),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: NileColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: mainImage == null
                                        ? const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.image_not_supported_outlined, size: 38),
                                                SizedBox(height: 8),
                                                Text('No images yet'),
                                              ],
                                            ),
                                          )
                                        : Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () {
                                                final initial = images.indexOf(mainImage);
                                                _showImageViewer(product, images, initial < 0 ? 0 : initial);
                                              },
                                              borderRadius: BorderRadius.circular(12),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  AdminImageFrame(
                                                    url: mainUrl,
                                                    expand: true,
                                                    fit: BoxFit.contain,
                                                    borderRadius: 12,
                                                    backgroundColor: NileColors.surfaceVariant,
                                                    label: 'Product image',
                                                  ),
                                                  Positioned(
                                                    left: 12,
                                                    bottom: 12,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withValues(alpha: .62),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.open_in_full, color: Colors.white, size: 15),
                                                            SizedBox(width: 6),
                                                            Text('Open gallery', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                  if (mainImage != null)
                                    Positioned(
                                      left: 10,
                                      top: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: NileColors.primary,
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: const Text(
                                          'MAIN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (mainImage != null)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: IconButton(
                                        tooltip: 'Delete main image',
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white.withValues(alpha: .94),
                                          minimumSize: const Size(38, 38),
                                        ),
                                        onPressed: () => _deleteImage(
                                          product['id'].toString(),
                                          mainImage,
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: NileColors.error,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  '${images.length} image${images.length == 1 ? '' : 's'}',
                                  style: NileTypography.bodySmall.copyWith(
                                    color: NileColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (product['is_active'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: NileColors.success.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: NileColors.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: images.isEmpty
                                        ? () => _addImages(product)
                                        : () => _showImageGallery(product, images),
                                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                                    label: Text(images.isEmpty ? 'Add Images' : 'Manage Images'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: busy ? null : () => _addImages(product),
                                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                                    label: const Text('Add'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
