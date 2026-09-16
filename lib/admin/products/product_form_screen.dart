/// Nile Tropical - Admin Product Form (Add / Edit)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/media_upload.dart';
import '../../shared/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId; // null = create new

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _fullDescController = TextEditingController();
  final _benefitsController = TextEditingController();
  final _howToUseController = TextEditingController();
  final _skuController = TextEditingController();
  final _variantNameController = TextEditingController(text: 'Default');
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _comparePriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _reorderController = TextEditingController(text: '5');
  final _imagePathController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _warningsController = TextEditingController();
  final List<Map<String, TextEditingController>> _extraVariants = [];

  bool _isFeatured = false;
  bool _isBestseller = false;
  bool _isNew = false;
  bool _isPromotional = false;
  bool _isActive = true;
  bool _saving = false;

  bool get isEditing => widget.productId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescController.dispose();
    _fullDescController.dispose();
    _benefitsController.dispose();
    _howToUseController.dispose();
    _skuController.dispose();
    _variantNameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _comparePriceController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _imagePathController.dispose();
    _ingredientsController.dispose();
    _warningsController.dispose();
    for (final v in _extraVariants) {
      for (final c in v.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final slug = _nameController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      // Field names match the schema (003_catalog.sql) and the rewritten
      // admin_upsert_product RPC in 019_admin_rpcs.sql — full_description
      // (not description), and all flags + long-form copy propagated.
      final product = {
        if (isEditing) 'id': widget.productId,
        'name': _nameController.text.trim(),
        'slug': slug,
        'short_description': _shortDescController.text.trim(),
        'full_description': _fullDescController.text.trim(),
        'benefits': _benefitsController.text.trim(),
        'how_to_use': _howToUseController.text.trim(),
        'ingredients': _ingredientsController.text.trim(),
        'warnings': _warningsController.text.trim(),
        'is_active': _isActive,
        'is_featured': _isFeatured,
        'is_bestseller': _isBestseller,
        'is_new': _isNew,
        'is_promotional': _isPromotional,
      };

      final priceVal = double.tryParse(_priceController.text) ?? 0;
      final costVal = double.tryParse(_costController.text);
      final compareVal = double.tryParse(_comparePriceController.text);

      final variants = <Map<String, dynamic>>[
        {
          'sku': _skuController.text.trim().isEmpty
              ? slug
              : _skuController.text.trim(),
          'name': _variantNameController.text.trim().isEmpty
              ? 'Default'
              : _variantNameController.text.trim(),
          'price': priceVal,
          if (costVal != null) 'cost_price': costVal,
          if (compareVal != null) 'compare_at_price': compareVal,
          'stock_quantity': int.tryParse(_stockController.text) ?? 0,
          'reorder_level': int.tryParse(_reorderController.text) ?? 5,
          'is_active': true,
        },
        ..._extraVariants.map((v) {
          final p = double.tryParse(v['price']!.text) ?? 0;
          final c = double.tryParse(v['cost']!.text);
          final cmp = double.tryParse(v['compare']!.text);
          return {
            'sku': v['sku']!.text.trim(),
            'name': v['name']!.text.trim(),
            'price': p,
            if (c != null) 'cost_price': c,
            if (cmp != null) 'compare_at_price': cmp,
            'stock_quantity': int.tryParse(v['stock']!.text) ?? 0,
            'reorder_level': int.tryParse(v['reorder']!.text) ?? 5,
            'is_active': true,
          };
        }),
      ];
      if (!Env.isConfigured) {
        throw StateError('Supabase is not configured. Product was not saved.');
      }
      await SupabaseService.client.rpc('admin_upsert_product', params: {
        'p_product': product,
        'p_variants': variants,
        'p_images': _imagePathController.text.trim().isEmpty
            ? <Map<String, dynamic>>[]
            : [
                {
                  'storage_path': _imagePathController.text.trim(),
                  'sort_order': 0,
                  'is_main': true,
                }
              ],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Product updated' : 'Product created'),
          backgroundColor: NileColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: NileColors.error),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Basic Info
            const Text('Basic Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name *'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortDescController,
              decoration: const InputDecoration(labelText: 'Short Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullDescController,
              decoration: const InputDecoration(labelText: 'Full Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _benefitsController,
              decoration: const InputDecoration(labelText: 'Benefits'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _howToUseController,
              decoration: const InputDecoration(labelText: 'How to Use'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ingredientsController,
              decoration: const InputDecoration(labelText: 'Ingredients'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _warningsController,
              decoration: const InputDecoration(labelText: 'Warnings'),
              maxLines: 2,
            ),
            const SizedBox(height: 28),

            // Pricing & Inventory
            const Text('Pricing & Inventory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU *'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imagePathController,
              decoration: const InputDecoration(
                labelText: 'Image storage path',
                hintText: 'product-images/{id}/hero.jpg',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final slug = _nameController.text
                      .trim()
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                  final path = await MediaUpload.pickAndUpload(
                    bucket: StorageService.productImages,
                    objectPath:
                        '${slug.isEmpty ? 'draft' : slug}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                    source: ImageSource.gallery,
                  );
                  if (path != null && mounted) {
                    setState(() => _imagePathController.text = path);
                  }
                },
                icon: const Icon(Icons.upload),
                label: const Text('Upload image'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _variantNameController,
              decoration: const InputDecoration(
                  labelText: 'Variant Name (e.g. 250g, 500ml)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price (UGX) *',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price (UGX)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _comparePriceController,
              decoration: const InputDecoration(
                labelText: 'Compare at Price (for discounts)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Opening Stock'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _reorderController,
                    decoration: const InputDecoration(labelText: 'Reorder Level'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _extraVariants.add({
                      'sku': TextEditingController(),
                      'name': TextEditingController(),
                      'price': TextEditingController(),
                      'cost': TextEditingController(),
                      'compare': TextEditingController(),
                      'stock': TextEditingController(text: '0'),
                      'reorder': TextEditingController(text: '5'),
                    });
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add variant'),
              ),
            ),
            ..._extraVariants.asMap().entries.map((e) {
              final i = e.key;
              final v = e.value;
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Variant ${i + 2}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextFormField(controller: v['sku'], decoration: const InputDecoration(labelText: 'SKU')),
                    TextFormField(controller: v['name'], decoration: const InputDecoration(labelText: 'Name')),
                    TextFormField(controller: v['price'], decoration: const InputDecoration(labelText: 'Price UGX'), keyboardType: TextInputType.number),
                    TextFormField(controller: v['stock'], decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
                  ],
                ),
              );
            }),
            const SizedBox(height: 28),

            // Display flags
            const Text('Display Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SwitchListTile(
              title: const Text('Featured'),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
              activeColor: NileColors.primary,
            ),
            SwitchListTile(
              title: const Text('Best Seller'),
              value: _isBestseller,
              onChanged: (v) => setState(() => _isBestseller = v),
              activeColor: NileColors.primary,
            ),
            SwitchListTile(
              title: const Text('New Arrival'),
              value: _isNew,
              onChanged: (v) => setState(() => _isNew = v),
              activeColor: NileColors.primary,
            ),
            SwitchListTile(
              title: const Text('Promotional'),
              value: _isPromotional,
              onChanged: (v) => setState(() => _isPromotional = v),
              activeColor: NileColors.primary,
            ),
            SwitchListTile(
              title: const Text('Active (visible in shop)'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeColor: NileColors.primary,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Create Product'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
