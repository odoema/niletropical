/// Nile Tropical - Admin Product Form
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/media_upload.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/supabase_service.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _short = TextEditingController();
  final _full = TextEditingController();
  final _benefits = TextEditingController();
  final _howToUse = TextEditingController();
  final _ingredients = TextEditingController();
  final _warnings = TextEditingController();
  final _sku = TextEditingController();
  final _variantName = TextEditingController(text: 'Default');
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _compare = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '5');

  bool _loading = true;
  bool _saving = false;
  bool _featured = false;
  bool _bestseller = false;
  bool _newArrival = false;
  bool _promotional = false;
  bool _active = true;
  String? _categoryId;
  String? _imagePath;
  String? _originalImagePath;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _existingImages = const [];
  String? _defaultVariantId;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _categories = List<Map<String, dynamic>>.from(
        await SupabaseService.client
            .from('categories')
            .select('id,name,slug,is_active')
            .eq('is_active', true)
            .order('sort_order'),
      );

      if (isEditing) {
        final product = await SupabaseService.client
            .from('products')
            .select('*, product_variants(*), product_images(*)')
            .eq('id', widget.productId!)
            .maybeSingle();
        if (product == null) {
          throw StateError('Product not found.');
        }

        _name.text = product['name']?.toString() ?? '';
        _short.text = product['short_description']?.toString() ?? '';
        _full.text = product['full_description']?.toString() ?? '';
        _benefits.text = product['benefits']?.toString() ?? '';
        _howToUse.text = product['how_to_use']?.toString() ?? '';
        _ingredients.text = product['ingredients']?.toString() ?? '';
        _warnings.text = product['warnings']?.toString() ?? '';
        _categoryId = product['category_id']?.toString();
        _featured = product['is_featured'] == true;
        _bestseller = product['is_bestseller'] == true;
        _newArrival = product['is_new'] == true;
        _promotional = product['is_promotional'] == true;
        _active = product['is_active'] != false;

        final variants = (product['product_variants'] as List?)
                ?.map((x) => Map<String, dynamic>.from(x as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        if (variants.isNotEmpty) {
          final v = variants.first;
          _defaultVariantId = v['id']?.toString();
          _sku.text = v['sku']?.toString() ?? '';
          _variantName.text = v['name']?.toString() ?? 'Default';
          _price.text = v['price']?.toString() ?? '';
          _cost.text = v['cost_price']?.toString() ?? '';
          _compare.text = v['compare_at_price']?.toString() ?? '';
          _stock.text = v['stock_quantity']?.toString() ?? '0';
          _reorder.text = v['reorder_level']?.toString() ?? '5';
        }

        _existingImages = (product['product_images'] as List?)
                ?.map((x) => Map<String, dynamic>.from(x as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        final main = _existingImages.where((x) => x['is_main'] == true);
        if (main.isNotEmpty) {
          _imagePath = main.first['storage_path']?.toString();
          _originalImagePath = _imagePath;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load product: $e'), backgroundColor: NileColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _short,
      _full,
      _benefits,
      _howToUse,
      _ingredients,
      _warnings,
      _sku,
      _variantName,
      _price,
      _cost,
      _compare,
      _stock,
      _reorder,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadImage() async {
    final slug = _name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final path = await MediaUpload.pickAndUpload(
      bucket: StorageService.productImages,
      objectPath: 'products/${slug.isEmpty ? 'draft' : slug}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      source: ImageSource.gallery,
    );
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (!Env.isConfigured) throw StateError('Supabase is not configured.');

      final slug = _name.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'-+'), '-');

      final product = <String, dynamic>{
        if (isEditing) 'id': widget.productId,
        'name': _name.text.trim(),
        'slug': slug,
        'short_description': _short.text.trim(),
        'full_description': _full.text.trim(),
        'benefits': _benefits.text.trim(),
        'how_to_use': _howToUse.text.trim(),
        'ingredients': _ingredients.text.trim(),
        'warnings': _warnings.text.trim(),
        'is_active': _active,
        'is_featured': _featured,
        'is_bestseller': _bestseller,
        'is_new': _newArrival,
        'is_promotional': _promotional,
      };

      final variant = <String, dynamic>{
        if (_defaultVariantId != null) 'id': _defaultVariantId,
        'sku': _sku.text.trim().isEmpty ? slug : _sku.text.trim(),
        'name': _variantName.text.trim().isEmpty ? 'Default' : _variantName.text.trim(),
        'price': double.tryParse(_price.text) ?? 0,
        if (_cost.text.trim().isNotEmpty) 'cost_price': double.tryParse(_cost.text),
        if (_compare.text.trim().isNotEmpty) 'compare_at_price': double.tryParse(_compare.text),
        'stock_quantity': int.tryParse(_stock.text) ?? 0,
        'reorder_level': int.tryParse(_reorder.text) ?? 5,
        'is_active': true,
      };

      final imagePayload = isEditing
          ? <Map<String, dynamic>>[]
          : (_imagePath == null
              ? <Map<String, dynamic>>[]
              : [
                  {
                    'storage_path': _imagePath,
                    'alt_text': _name.text.trim(),
                    'sort_order': 0,
                    'is_main': true,
                  }
                ]);

      // Do not depend on the legacy admin_upsert_product RPC here.
      // Production may be running without that RPC in PostgREST's schema cache.
      // Use the same authenticated Supabase client for direct, auditable writes.
      String productId;

      if (isEditing) {
        productId = widget.productId!;
        await SupabaseService.client
            .from('products')
            .update(product)
            .eq('id', productId);

        if (_defaultVariantId != null) {
          await SupabaseService.client
              .from('product_variants')
              .update(variant)
              .eq('id', _defaultVariantId!);
        } else {
          final insertedVariant = await SupabaseService.client
              .from('product_variants')
              .insert({
                'product_id': productId,
                ...variant,
              })
              .select('id')
              .single();
          _defaultVariantId = insertedVariant['id']?.toString();
        }
      } else {
        final insertedProduct = await SupabaseService.client
            .from('products')
            .insert(product)
            .select('id')
            .single();
        productId = insertedProduct['id'].toString();

        await SupabaseService.client
            .from('product_variants')
            .insert({
              'product_id': productId,
              ...variant,
            });

        if (imagePayload.isNotEmpty) {
          await SupabaseService.client
              .from('product_images')
              .insert({
                'product_id': productId,
                ...imagePayload.first,
              });
        }
      }

      if (isEditing && _imagePath != null && _imagePath != _originalImagePath) {
        // Replace the existing main-image row instead of creating a second
        // row. This keeps the catalogue reference stable and avoids ending
        // up with a product whose image is uploaded but not reflected in the
        // storefront.
        final existingImages = await SupabaseService.client
            .from('product_images')
            .select('id,storage_path,is_main,sort_order')
            .eq('product_id', productId)
            .order('sort_order');

        final rows = List<Map<String, dynamic>>.from(existingImages);
        final target = rows.firstWhere(
          (row) => row['is_main'] == true,
          orElse: () => rows.isNotEmpty ? rows.first : <String, dynamic>{},
        );

        if (target['id'] != null) {
          await SupabaseService.client
              .from('product_images')
              .update({'is_main': false})
              .eq('product_id', productId);

          await SupabaseService.client
              .from('product_images')
              .update({
                'storage_path': _imagePath,
                'alt_text': _name.text.trim(),
                'sort_order': 0,
                'is_main': true,
              })
              .eq('id', target['id']);
        } else {
          await SupabaseService.client.from('product_images').insert({
            'product_id': productId,
            'storage_path': _imagePath,
            'alt_text': _name.text.trim(),
            'sort_order': 0,
            'is_main': true,
          });
        }

        // Do not delete the old file until the database reference has been
        // successfully updated. That prevents a broken catalogue reference.
        if (_originalImagePath != null && _originalImagePath!.isNotEmpty) {
          try {
            await StorageService.delete(
              bucket: StorageService.productImages,
              path: _originalImagePath!,
            );
          } catch (_) {}
        }
      }
      if (_categoryId != null && _categoryId!.isNotEmpty) {
        await SupabaseService.client
            .from('products')
            .update({'category_id': _categoryId})
            .eq('id', productId);
      } else {
        await SupabaseService.client
            .from('products')
            .update({'category_id': null})
            .eq('id', productId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Product updated successfully' : 'Product created successfully'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _sectionTitle('Basic information'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Product name *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Uncategorised'),
                ),
                ..._categories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c['id']?.toString(),
                    child: Text(c['name']?.toString() ?? ''),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _short, decoration: const InputDecoration(labelText: 'Short description'), maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _full, decoration: const InputDecoration(labelText: 'Full description'), maxLines: 5),
            const SizedBox(height: 12),
            TextFormField(controller: _benefits, decoration: const InputDecoration(labelText: 'Benefits'), maxLines: 4),
            const SizedBox(height: 12),
            TextFormField(controller: _howToUse, decoration: const InputDecoration(labelText: 'How to use'), maxLines: 4),
            const SizedBox(height: 12),
            TextFormField(controller: _ingredients, decoration: const InputDecoration(labelText: 'Ingredients'), maxLines: 4),
            const SizedBox(height: 12),
            TextFormField(controller: _warnings, decoration: const InputDecoration(labelText: 'Warnings'), maxLines: 3),

            const SizedBox(height: 28),
            _sectionTitle('Product images'),
            if (_imagePath != null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: NileColors.surfaceVariant,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  StorageService.resolvePublicUrl(_imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _uploadImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_imagePath == null ? 'Upload product image' : 'Replace main image'),
            ),
            if (_existingImages.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${_existingImages.length} catalogue images already attached. Use Product Images to manage the full gallery.'),
              ),

            const SizedBox(height: 28),
            _sectionTitle('Pricing & inventory'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(labelText: 'SKU *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'SKU is required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(controller: _variantName, decoration: const InputDecoration(labelText: 'Variant name')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Selling price (UGX) *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Price is required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _cost, decoration: const InputDecoration(labelText: 'Cost price (UGX)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _compare, decoration: const InputDecoration(labelText: 'Compare-at price'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _stock, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _reorder, decoration: const InputDecoration(labelText: 'Reorder level'), keyboardType: TextInputType.number)),
              ],
            ),

            const SizedBox(height: 28),
            _sectionTitle('Storefront visibility'),
            SwitchListTile(title: const Text('Featured'), value: _featured, onChanged: (v) => setState(() => _featured = v)),
            SwitchListTile(title: const Text('Bestseller'), value: _bestseller, onChanged: (v) => setState(() => _bestseller = v)),
            SwitchListTile(title: const Text('New arrival'), value: _newArrival, onChanged: (v) => setState(() => _newArrival = v)),
            SwitchListTile(title: const Text('Promotional'), value: _promotional, onChanged: (v) => setState(() => _promotional = v)),
            SwitchListTile(title: const Text('Active — visible in shop'), value: _active, onChanged: (v) => setState(() => _active = v)),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : (isEditing ? 'Save changes' : 'Create product')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _saving ? null : () => context.pop(), child: const Text('Cancel')),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      );
}
