import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/services/media_upload.dart';
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

  Future<void> _replaceImage(Map<String, dynamic> product) async {
    final productId = product['id'] as String;
    final slug = (product['slug'] as String?)?.trim().isNotEmpty == true
        ? product['slug'] as String
        : productId;
    setState(() => _busyProductId = productId);

    try {
      final path = await MediaUpload.pickAndUpload(
        bucket: StorageService.productImages,
        objectPath:
            'products/$slug/${DateTime.now().millisecondsSinceEpoch}.jpg',
        source: ImageSource.gallery,
      );

      if (path == null || !mounted) {
        if (mounted) setState(() => _busyProductId = null);
        return;
      }

      await SupabaseService.client.rpc(
        'admin_replace_product_main_image',
        params: {
          'p_product_id': productId,
          'p_storage_path': path,
          'p_alt_text': product['name'],
        },
      );

      if (!mounted) return;
      setState(() {
        _busyProductId = null;
        _products = _loadProducts();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product['name']} image updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image update failed: $e'),
          backgroundColor: NileColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Images'),
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                final images =
                    (product['product_images'] as List?)?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                final main = images.where((x) => x['is_main'] == true).isNotEmpty
                    ? images.firstWhere((x) => x['is_main'] == true)
                    : (images.isNotEmpty ? images.first : null);
                final path = main?['storage_path'] as String?;
                final url = StorageService.resolvePublicUrl(path);
                final isBusy = _busyProductId == product['id'];

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: url.isEmpty
                              ? const Icon(Icons.image_not_supported_outlined, size: 36)
                              : Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    size: 36,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] as String? ?? 'Unnamed product',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                path ?? 'No image',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: isBusy ? null : () => _replaceImage(product),
                          icon: isBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_outlined),
                          label: Text(isBusy ? 'Uploading…' : 'Replace'),
                        ),
                      ],
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
