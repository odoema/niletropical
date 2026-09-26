import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/error_reporter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/supabase_service.dart';

class SeoHealthScreen extends StatefulWidget {
  const SeoHealthScreen({super.key});
  @override State<SeoHealthScreen> createState() => _SeoHealthScreenState();
}

class _SeoHealthScreenState extends State<SeoHealthScreen> {
  bool _loading = true;
  String? _error;
  List<_SeoProduct> _products = const [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await SupabaseService.client
          .from('products')
          .select('id,name,slug,short_description,full_description,brand,category_id,is_active,deleted_at,product_variants(id,sku,name,price,stock_quantity,is_active),product_images(id,storage_path,url,alt_text,is_main)')
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('name');
      final products = (rows as List)
          .map((r) => _SeoProduct.fromMap(Map<String, dynamic>.from(r))).toList();
      if (mounted) setState(() { _products = products; _loading = false; });
    } catch (e, st) {
      await ErrorReporter.report(e, stackTrace: st, source: 'admin_seo', action: 'load_seo_health');
      if (mounted) setState(() { _loading = false; _error = ErrorReporter.friendlyMessage(e); });
    }
  }

  @override Widget build(BuildContext context) {
    final issues = _products.fold<int>(0, (n, p) => n + p.issues.length);
    final healthy = _products.where((p) => p.issues.isEmpty).length;
    final score = _products.isEmpty ? 0 : ((healthy / _products.length) * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('SEO Health'), actions: [
        IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? _ErrorView(message: _error!, onRetry: _load)
        : RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Metric(label: 'SEO score', value: '$score%', icon: Icons.search),
              _Metric(label: 'Products checked', value: '${_products.length}', icon: Icons.inventory_2_outlined),
              _Metric(label: 'Healthy products', value: '$healthy', icon: Icons.check_circle_outline),
              _Metric(label: 'Issues found', value: '$issues', icon: Icons.warning_amber_outlined),
            ]),
            const SizedBox(height: 24),
            Text('Catalogue SEO readiness', style: NileTypography.titleLarge),
            const SizedBox(height: 6),
            Text('This checks the live catalogue that feeds the automatic SEO pages, sitemap and merchant feed.', style: NileTypography.bodyMedium),
            const SizedBox(height: 14),
            if (_products.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No active products found.')))
            else ..._products.map((p) => _ProductCard(product: p)),
          ]),
        ),
    );
  }
}

class _SeoProduct {
  final String id, name, slug;
  final String? description, brand, categoryId;
  final List<_Variant> variants;
  final List<_Image> images;
  _SeoProduct({required this.id, required this.name, required this.slug, this.description, this.brand, this.categoryId, required this.variants, required this.images});

  factory _SeoProduct.fromMap(Map<String, dynamic> m) => _SeoProduct(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? 'Unnamed product',
    slug: m['slug']?.toString() ?? '',
    description: (m['short_description'] ?? m['full_description'])?.toString(),
    brand: m['brand']?.toString(),
    categoryId: m['category_id']?.toString(),
    variants: ((m['product_variants'] as List?) ?? []).map((v) => _Variant.fromMap(Map<String, dynamic>.from(v))).where((v) => v.active).toList(),
    images: ((m['product_images'] as List?) ?? []).map((v) => _Image.fromMap(Map<String, dynamic>.from(v))).toList(),
  );

  List<String> get issues {
    final out = <String>[];
    if (slug.trim().isEmpty) out.add('Missing SEO slug');
    if ((description ?? '').trim().length < 70) out.add('Description needs more detail');
    if ((brand ?? '').trim().isEmpty) out.add('Brand is missing');
    final titleLength = (name.trim() + ' | Nile Tropical Uganda').length;
    if (titleLength < 20 || titleLength > 60) out.add('SEO title needs tuning');
    if ((description ?? '').trim().length > 155) out.add('Description is too long');
    if ((categoryId ?? '').trim().isEmpty) out.add('Product category missing');
    if (images.isEmpty) out.add('No product image');
    if (images.any((i) => i.alt.trim().isEmpty)) out.add('Image alt text missing');
    if (variants.isEmpty) out.add('No active variant');
    if (variants.any((v) => v.sku.trim().isEmpty)) out.add('Variant SKU missing');
    if (variants.any((v) => v.price <= 0)) out.add('Variant price missing/invalid');
    return out;
  }
}

class _Variant {
  final String sku; final double price; final bool active;
  _Variant({required this.sku, required this.price, required this.active});
  factory _Variant.fromMap(Map<String, dynamic> m) => _Variant(
    sku: m['sku']?.toString() ?? '', price: double.tryParse(m['price']?.toString() ?? '') ?? 0, active: m['is_active'] != false);
}

class _Image {
  final String alt;
  _Image({required this.alt});
  factory _Image.fromMap(Map<String, dynamic> m) => _Image(alt: m['alt_text']?.toString() ?? '');
}

class _Metric extends StatelessWidget {
  final String label, value; final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override Widget build(BuildContext context) => SizedBox(width: 190, child: Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Row(children: [
      Icon(icon, color: NileColors.primary), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: NileTypography.headlineSmall.copyWith(color: NileColors.primary, fontWeight: FontWeight.w700)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: NileTypography.caption),
      ]))
    ])
  )));
}

class _ProductCard extends StatelessWidget {
  final _SeoProduct product;
  const _ProductCard({required this.product});

  String _recommendation(String issue) {
    if (issue.contains('Description')) return 'Write a useful 70–155 character search description that explains the product and its main customer benefit.';
    if (issue.contains('Brand')) return 'Set the real product brand so structured data and catalogue feeds identify the manufacturer correctly.';
    if (issue.contains('title')) return 'Keep the generated product title concise; aim for a clear product name plus the Nile Tropical suffix within about 60 characters.';
    if (issue.contains('category')) return 'Assign the most specific active catalogue category to strengthen navigation, breadcrumbs and category discovery.';
    if (issue.contains('image')) return 'Add a high-quality main product image. Product pages perform better when the primary visual clearly represents the item.';
    if (issue.contains('alt')) return 'Add concise, accurate alt text describing the product image for accessibility and image search.';
    if (issue.contains('variant')) return 'Create at least one active sellable variant so the product page can expose price and availability.';
    if (issue.contains('SKU')) return 'Give every active variant a stable SKU so catalogue feeds can identify the exact sellable item.';
    if (issue.contains('price')) return 'Set a valid positive selling price so Product structured data and merchant feeds can expose an offer.';
    if (issue.contains('slug')) return 'Use a short, readable, stable URL slug based on the product name.';
    return 'Review this product for completeness before publishing it to the SEO layer.';
  }

  @override
  Widget build(BuildContext context) {
    final ok = product.issues.isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            onTap: () => product.id.isEmpty ? null : context.push('/admin/products/${product.id}'),
            mouseCursor: SystemMouseCursors.click,
            leading: CircleAvatar(
              backgroundColor: (ok ? NileColors.success : NileColors.warning).withOpacity(.12),
              child: Icon(ok ? Icons.check : Icons.warning_amber_rounded, color: ok ? NileColors.success : NileColors.warning),
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(ok ? 'Ready for automatic SEO publishing' : product.issues.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: ok
                ? const Icon(Icons.check_circle_outline, color: NileColors.success)
                : Text('${product.issues.length} ISSUE${product.issues.length == 1 ? '' : 'S'}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NileColors.warning)),
          ),
          if (!ok)
            ExpansionTile(
              leading: const Icon(Icons.lightbulb_outline, size: 20),
              title: const Text('SEO recommendations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              children: product.issues.map((issue) => ListTile(
                dense: true,
                leading: const Icon(Icons.arrow_right, size: 18),
                title: Text(issue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: Text(_recommendation(issue), style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.build_outlined, size: 17),
                onTap: () => product.id.isEmpty ? null : context.push('/admin/products/${product.id}'),
              )).toList(),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message; final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 42), const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center), const SizedBox(height: 12),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
    ])
  ));
}
