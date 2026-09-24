import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class ProductImageManagerScreen extends ConsumerStatefulWidget {
  const ProductImageManagerScreen({super.key});

  @override
  ConsumerState<ProductImageManagerScreen> createState() =>
      _ProductImageManagerScreenState();
}

class _ProductImageManagerScreenState
    extends ConsumerState<ProductImageManagerScreen> {
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
    final raw = product['name']?.toString() ?? '';
    // Product imports may contain embedded line breaks between characters.
    // Collapse all whitespace so names always render as normal catalogue text.
    final normalized = raw.replaceAll(RegExp(r'\\s+'), ' ').trim();
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
      final existing = await SupabaseService.client
          .from('product_images')
          .select('id,is_main')
          .eq('product_id', productId);

      var hasMain = (existing as List).any(
        (row) => (row as Map<String, dynamic>)['is_main'] == true,
      );

      for (var i = 0; i < picked.length; i++) {
        final file = picked[i];
        final bytes = await file.readAsBytes();
        final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
        final safeName = file.name
            .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-')
            .replaceAll(RegExp(r'-+'), '-');
        final path =
            'products/${_slugFor(product)}/${DateTime.now().millisecondsSinceEpoch}-$i-$safeName';

        await StorageService.upload(
          bucket: StorageService.productImages,
          objectPath: path,
          bytes: bytes,
          contentType: file.mimeType ?? 'image/$ext',
        );

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
        SnackBar(content: Text('${picked.length} image${picked.length == 1 ? '' : 's'} added to ' + _displayName(product))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: NileColors.error),
      );
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _setMain(String productId, String imageId) async {
    try {
      await SupabaseService.client
          .from('product_images')
          .update({'is_main': false})
          .eq('product_id', productId);
      await SupabaseService.client
          .from('product_images')
          .update({'is_main': true, 'sort_order': 0})
          .eq('id', imageId);
      if (!mounted) return;
      setState(() => _products = _loadProducts());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Main product image updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set main image: $e'), backgroundColor: NileColors.error),
      );
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
      await StorageService.delete(bucket: StorageService.productImages, path: path);
      await SupabaseService.client.from('product_images').delete().eq('id', imageId);
      if (image['is_main'] == true) {
        final remaining = await SupabaseService.client
            .from('product_images')
            .select('id')
            .eq('product_id', productId)
            .order('sort_order')
            .limit(1);
        if ((remaining as List).isNotEmpty) {
          await SupabaseService.client
              .from('product_images')
              .update({'is_main': true, 'sort_order': 0})
              .eq('id', remaining.first['id']);
        }
      }
      if (!mounted) return;
      setState(() => _products = _loadProducts());
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
        title: const Text('Product Image Manager'),
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final product = products[index];
                final images = (product['product_images'] as List?)
                        ?.map((x) => Map<String, dynamic>.from(x as Map))
                        .toList() ??
                    <Map<String, dynamic>>[];
                final busy = _busyProductId == product['id'];

                return SizedBox(
                  width: double.infinity,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 560;
                                final title = Text(
                                  _displayName(product),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                                final action = FilledButton.icon(
                                  onPressed: busy ? null : () => _addImages(product),
                                  icon: busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.add_photo_alternate_outlined),
                                  label: Text(busy ? 'Uploading…' : 'Add images'),
                                );
                                if (compact) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      title,
                                      const SizedBox(height: 10),
                                      action,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(child: title),
                                    const SizedBox(width: 16),
                                    action,
                                  ],
                                );
                              },
                            ),
                        const SizedBox(height: 12),
                        if (images.isEmpty)
                          Container(
                            height: 130,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: NileColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported_outlined, size: 40),
                                SizedBox(height: 6),
                                Text('No product images yet'),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 190,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, imageIndex) {
                                final image = images[imageIndex];
                                final path = image['storage_path']?.toString();
                                final url = StorageService.resolvePublicUrl(path);
                                final isMain = image['is_main'] == true;
                                return SizedBox(
                                  width: 155,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: url.isEmpty
                                                    ? const Icon(Icons.broken_image_outlined, size: 40)
                                                    : Image.network(
                                                        url,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => const Center(
                                                          child: Icon(Icons.broken_image_outlined, size: 40),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            if (isMain)
                                              Positioned(
                                                left: 6,
                                                top: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: NileColors.primary,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'MAIN',
                                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              right: 4,
                                              top: 4,
                                              child: IconButton(
                                                tooltip: 'Delete',
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.white.withValues(alpha: .9),
                                                ),
                                                onPressed: () => _deleteImage(product['id'].toString(), image),
                                                icon: const Icon(Icons.delete_outline, color: NileColors.error),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        image['alt_text']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      TextButton(
                                        onPressed: isMain
                                            ? null
                                            : () => _setMain(product['id'].toString(), image['id'].toString()),
                                        child: Text(isMain ? 'Main image' : 'Set as main'),
                                      ),
                                    ],
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
            ),
          );
        },
      ),
    );
  }
}
