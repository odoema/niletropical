import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/errors/error_reporter.dart';

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

  Future<void> _editAltText(Map<String, dynamic> image, String productName) async {
    final controller = TextEditingController(text: image['alt_text']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit image alt text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 160,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Alt text',
            hintText: 'Describe this product image for search and accessibility',
            helperText: 'Use a concise, accurate description. Do not keyword-stuff.',
            suffixIcon: IconButton(tooltip: 'Use product name', onPressed: () => controller.text = productName, icon: const Icon(Icons.auto_fix_high_outlined)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final imageId = image['id']?.toString();
    if (imageId == null || imageId.isEmpty) return;
    try {
      await SupabaseService.client.from('product_images').update({'alt_text': value}).eq('id', imageId);
      if (!mounted) return;
      setState(() => _products = _loadProducts());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image alt text updated')));
    } catch (e, st) {
      await ErrorReporter.report(e, stackTrace: st, source: 'admin_product_images', action: 'update_image_alt_text');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update alt text. ' + ErrorReporter.friendlyMessage(e)), backgroundColor: NileColors.error));
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

  Widget _imageTile(Map<String, dynamic> product, Map<String, dynamic> image) {
    final path = image['storage_path']?.toString();
    final url = StorageService.resolvePublicUrl(path);
    final isMain = image['is_main'] == true;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: url.isEmpty
                ? const Center(child: Icon(Icons.broken_image_outlined, size: 32))
                : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 32))),
          ),
          if (isMain)
            Positioned(left: 7, top: 7, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(color: NileColors.primary, borderRadius: BorderRadius.circular(6)),
              child: const Text('MAIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            )),
          Positioned(
            right: 4, top: 4,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Edit alt text',
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .92), padding: const EdgeInsets.all(7), minimumSize: const Size(34, 34)),
                onPressed: () => _editAltText(image, _displayName(product)),
                icon: Icon(Icons.accessibility_new_outlined, color: (image['alt_text']?.toString().trim().isNotEmpty ?? false) ? NileColors.primary : NileColors.warning, size: 18),
              ),
              IconButton(
                tooltip: 'Delete image',
              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .92), padding: const EdgeInsets.all(7), minimumSize: const Size(34, 34)),
              onPressed: () => _deleteImage(product['id'].toString(), image),
                icon: const Icon(Icons.delete_outline, color: NileColors.error, size: 18),
              ),
            ]),
          ),
          Positioned(
            left: 5, right: 5, bottom: 5,
            child: SizedBox(
              height: 32,
              child: isMain
                  ? const DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white70),
                      child: Center(child: Text('Main image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    )
                  : TextButton(
                      style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .92), padding: EdgeInsets.zero),
                      onPressed: () => _setMain(product['id'].toString(), image['id'].toString()),
                      child: const Text('Set as main', style: TextStyle(fontSize: 11)),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Image Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        foregroundColor: Colors.white,
        backgroundColor: NileColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/products')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load products: ${snapshot.error}')));
          final products = snapshot.data ?? const [];
          if (products.isEmpty) return const Center(child: Text('No products found.'));

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _products = _loadProducts());
              await _products;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1300 ? 3 : constraints.maxWidth >= 820 ? 2 : 1;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: columns == 1 ? 320 : 300,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final images = (product['product_images'] as List?)
                            ?.map((x) => Map<String, dynamic>.from(x as Map))
                            .toList() ?? <Map<String, dynamic>>[];
                    final busy = _busyProductId == product['id'];

                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(_displayName(product), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Add images',
                                  onPressed: busy ? null : () => _addImages(product),
                                  icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate_outlined),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Expanded(
                              child: images.isEmpty
                                  ? Container(
                                      decoration: BoxDecoration(color: NileColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_not_supported_outlined, size: 34), SizedBox(height: 6), Text('No images yet')]),
                                    )
                                  : GridView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: images.length == 1 ? 1 : images.length == 2 ? 2 : 3,
                                        crossAxisSpacing: 7,
                                        mainAxisSpacing: 7,
                                      ),
                                      itemCount: images.length > 6 ? 6 : images.length,
                                      itemBuilder: (_, i) => _imageTile(product, images[i]),
                                    ),
                            ),
                            const SizedBox(height: 7),
                            if (images.any((image) => (image['alt_text']?.toString().trim().isEmpty ?? true)))
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Row(children: [Icon(Icons.warning_amber_rounded, size: 14, color: NileColors.warning), SizedBox(width: 4), Text('Alt text needs attention', style: TextStyle(fontSize: 10, color: NileColors.warning, fontWeight: FontWeight.w700))]),
                              ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text('${images.length} image${images.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodySmall),
                                const Spacer(),
                                if (product['is_active'] == true) const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NileColors.success)),
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
}
