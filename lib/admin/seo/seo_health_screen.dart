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
  List<_SeoCategory> _categories = const [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('products')
            .select('id,name,slug,short_description,full_description,brand,category_id,is_active,deleted_at,product_variants(id,sku,name,price,stock_quantity,is_active),product_images(id,storage_path,url,alt_text,is_main)')
            .eq('is_active', true)
            .isFilter('deleted_at', null)
            .order('name'),
        SupabaseService.client
            .from('categories')
            .select('id,name,slug,description,is_active,products:products!category_id(count)')
            .eq('is_active', true)
            .order('sort_order'),
      ]);

      final productRows = results[0] as List;
      final categoryRows = results[1] as List;
      final products = productRows
          .map((r) => _SeoProduct.fromMap(Map<String, dynamic>.from(r)))
          .toList();

      final categories = categoryRows.map((r) {
        final m = Map<String, dynamic>.from(r);
        final relation = (m['products'] as List?) ?? const [];
        final count = relation.isEmpty
            ? 0
            : int.tryParse((relation.first as Map)['count']?.toString() ?? '0') ?? 0;
        m['product_count'] = count;
        return _SeoCategory.fromMap(m);
      }).toList();

      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _loading = false;
        });
      }
    } catch (e, st) {
      await ErrorReporter.report(e, stackTrace: st, source: 'admin_seo', action: 'load_seo_health');
      if (mounted) setState(() { _loading = false; _error = ErrorReporter.friendlyMessage(e); });
    }
  }

  @override Widget build(BuildContext context) {
    final criticalIssues = _products.fold<int>(0, (n, p) => n + p.criticalIssues.length);
    final recommendedIssues = _products.fold<int>(0, (n, p) => n + p.recommendedIssues.length);
    final ready = _products.where((p) => p.ready).length;
    final readiness = _products.isEmpty ? 0 : ((ready / _products.length) * 100).round();
    final categoryIssues = _categories.fold<int>(0, (n, c) => n + c.issues.length);
    final healthyCategories = _categories.where((c) => c.issues.isEmpty).length;

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
              _Metric(label: 'Critical readiness', value: '$readiness%', icon: Icons.verified_outlined),
              _Metric(label: 'Products checked', value: '${_products.length}', icon: Icons.inventory_2_outlined),
              _Metric(label: 'Critical issues', value: '$criticalIssues', icon: Icons.error_outline),
              _Metric(label: 'Recommendations', value: '$recommendedIssues', icon: Icons.lightbulb_outline),
            ]),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: NileColors.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'Critical readiness covers fields required for a useful crawlable product page and offer. Recommendations improve titles, descriptions, branding and image discovery without blocking publication.',
                    style: NileTypography.bodyMedium,
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Text('Catalogue SEO readiness', style: NileTypography.titleLarge),
            const SizedBox(height: 6),
            Text('Live products feed the automatic product pages, sitemap and merchant feed.', style: NileTypography.bodyMedium),
            const SizedBox(height: 14),
            if (_products.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No active products found.')))
            else ..._products.map((p) => _ProductCard(product: p)),
            const SizedBox(height: 26),
            Text('Category SEO readiness', style: NileTypography.titleLarge),
            const SizedBox(height: 6),
            Text('${_categories.length} active categories · $healthyCategories healthy · $categoryIssues recommendations/issues', style: NileTypography.bodyMedium),
            const SizedBox(height: 12),
            if (_categories.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No active categories found.')))
            else ..._categories.map((c) => _CategoryCard(category: c)),
          ]),
        ),
    );
  }
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
    if (issue.contains('title')) return 'Keep the generated product title concise; the SEO generator will trim long names to its target length.';
    if (issue.contains('category')) return 'Assign the most specific active catalogue category to strengthen navigation, breadcrumbs and category discovery.';
    if (issue.contains('image')) return 'Add a high-quality product image. The SEO page needs a real product visual for rich product presentation.';
    if (issue.contains('alt')) return 'Add concise, accurate alt text describing the product image for accessibility and image search.';
    if (issue.contains('variant')) return 'Create at least one active sellable variant so the product page can expose price and availability.';
    if (issue.contains('SKU')) return 'Give every active variant a stable SKU so catalogue feeds can identify the exact sellable item.';
    if (issue.contains('price')) return 'Set a valid positive selling price so Product structured data and merchant feeds can expose an offer.';
    if (issue.contains('slug')) return 'Use a short, readable, stable URL slug based on the product name.';
    return 'Review this product for completeness before publishing it to the SEO layer.';
  }

  Widget _issueGroup(String title, List<String> issues, BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      leading: Icon(title == 'Critical fixes' ? Icons.error_outline : Icons.lightbulb_outline, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      children: issues.map((issue) => ListTile(
        dense: true,
        leading: const Icon(Icons.arrow_right, size: 18),
        title: Text(issue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        subtitle: Text(_recommendation(issue), style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.build_outlined, size: 17),
        onTap: () => product.id.isEmpty ? null : context.push('/admin/products/${product.id}'),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final critical = product.criticalIssues;
    final recommended = product.recommendedIssues;
    final ok = product.ready;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        ListTile(
          onTap: () => product.id.isEmpty ? null : context.push('/admin/products/${product.id}'),
          mouseCursor: SystemMouseCursors.click,
          leading: CircleAvatar(
            backgroundColor: (ok ? NileColors.success : NileColors.warning).withOpacity(.12),
            child: Icon(ok ? Icons.check : Icons.warning_amber_rounded, color: ok ? NileColors.success : NileColors.warning),
          ),
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            ok
                ? (recommended.isEmpty ? 'Ready for automatic SEO publishing' : 'Publishable; ${recommended.length} recommendation(s) to improve discoverability')
                : '${critical.length} critical fix(es) · ${recommended.length} recommendation(s)',
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          trailing: ok
              ? const Icon(Icons.check_circle_outline, color: NileColors.success)
              : Text('${critical.length} CRITICAL', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NileColors.error)),
        ),
        _issueGroup('Critical fixes', critical, context),
        _issueGroup('SEO recommendations', recommended, context),
      ]),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _SeoCategory category;
  const _CategoryCard({required this.category});

  String _recommendation(String issue) {
    if (issue.contains('slug')) return 'Use a short, stable category URL slug based on the category name.';
    if (issue.contains('title')) return 'Keep the category name concise enough for the generated SEO title to stay within its target length.';
    if (issue.contains('description')) return 'Write a clear 70–155 character category description explaining what shoppers can find here.';
    if (issue.contains('no active')) return 'Add active products to this category or deactivate the category until it has useful catalogue content.';
    return 'Review this category before relying on it as a search landing page.';
  }

  @override
  Widget build(BuildContext context) {
    final ok = category.issues.isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (ok ? NileColors.success : NileColors.warning).withOpacity(.12),
          child: Icon(ok ? Icons.check : Icons.warning_amber_rounded, color: ok ? NileColors.success : NileColors.warning),
        ),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${category.productCount} active product(s) · ${ok ? 'SEO ready' : '${category.issues.length} issue(s)'}'),
        children: ok
            ? const [ListTile(dense: true, leading: Icon(Icons.check_circle_outline, color: NileColors.success), title: Text('Category is ready for crawlable SEO publishing.'))]
            : category.issues.map((issue) => ListTile(
                dense: true,
                leading: const Icon(Icons.arrow_right),
                title: Text(issue, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                subtitle: Text(_recommendation(issue), style: const TextStyle(fontSize: 12)),
                onTap: () => category.id.isEmpty ? null : context.push('/admin/categories'),
              )).toList(),
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
