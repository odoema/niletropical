import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/models/product.dart';
import '../../shared/services/supabase_service.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  bool _loading = true;
  String? _error;
  String _title = 'Category';
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Connect Supabase to load this category.';
      });
      return;
    }
    try {
      final cats = await SupabaseService.fetchCategories();
      final cat = cats.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['slug'] == widget.slug,
            orElse: () => null,
          );
      if (cat == null) {
        setState(() {
          _loading = false;
          _error = 'Category not found';
        });
        return;
      }
      final rows = await SupabaseService.client
          .from('products')
          .select('*, product_variants (*), product_images (*)')
          .eq('is_active', true)
          .eq('category_id', cat['id'])
          .isFilter('deleted_at', null);
      if (!mounted) return;
      setState(() {
        _title = cat['name']?.toString() ?? widget.slug;
        _products = List<Map<String, dynamic>>.from(rows).map(Product.fromJson).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NileAppBar(title: _title),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(title: _title, message: _error)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    NileSpacing.md,
                    NileSpacing.sm,
                    NileSpacing.md,
                    NileSpacing.lg,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    mainAxisSpacing: NileSpacing.md,
                    crossAxisSpacing: NileSpacing.sm,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (_, i) => ProductCard(product: _products[i]),
                ),
    );
  }
}
