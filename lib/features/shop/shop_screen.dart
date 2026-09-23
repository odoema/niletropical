/// Nile Tropical - Shop Screen (search, sort, filters)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/models/product.dart';
import '../../shared/providers/product_provider.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String? _search;
  String _sort = 'newest';
  String? _flag;
  bool _inStockOnly = false;
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(_search));

    return Scaffold(
      appBar: const NileAppBar(title: 'Shop'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(NileSpacing.md, NileSpacing.sm, NileSpacing.md, 0),
            child: NileSearchField(
              hint: 'Search products…',
              onChanged: (v) {
                setState(() => _search = v.isEmpty ? null : v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NileSpacing.md, vertical: 8),
            child: Row(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _flag,
                    hint: const Text('All'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'featured', child: Text('Featured')),
                      DropdownMenuItem(value: 'bestseller', child: Text('Bestsellers')),
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'promo', child: Text('Promo')),
                    ],
                    onChanged: (v) => setState(() => _flag = v),
                  ),
                ),
                const SizedBox(width: 12),
                ...(() {
                  final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
                  if (cats.isEmpty) return <Widget>[];
                  return [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _categoryId,
                        hint: const Text('Category'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All cats')),
                          ...cats.map((c) => DropdownMenuItem(
                                value: c['id']?.toString(),
                                child: Text(c['name']?.toString() ?? ''),
                              )),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ];
                })(),
                FilterChip(
                  label: const Text('In stock'),
                  selected: _inStockOnly,
                  onSelected: (v) => setState(() => _inStockOnly = v),
                ),
                const SizedBox(width: 12),
                Text('Sort', style: NileTypography.labelMedium),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'price_asc', child: Text('Price ↑')),
                      DropdownMenuItem(value: 'price_desc', child: Text('Price ↓')),
                      DropdownMenuItem(value: 'name', child: Text('Name')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'newest'),
                    style: NileTypography.bodyMedium.copyWith(color: NileColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                var list = List<Product>.from(products);
                if (_flag == 'featured') list = list.where((p) => p.isFeatured).toList();
                if (_flag == 'bestseller') list = list.where((p) => p.isBestseller).toList();
                if (_flag == 'new') list = list.where((p) => p.isNew).toList();
                if (_flag == 'promo') list = list.where((p) => p.isPromotional).toList();
                if (_inStockOnly) {
                  list = list
                      .where((p) => p.variants.any((v) => v.inStock))
                      .toList();
                }
                if (_categoryId != null) {
                  list = list.where((p) => p.categoryId == _categoryId).toList();
                }
                final sorted = _sortProducts(list);
                if (sorted.isEmpty) {
                  return const NileEmptyState(
                    title: 'No products found',
                    message: 'Try a different search.',
                    icon: Icons.search_off,
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(NileSpacing.md),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: NileSpacing.sm,
                    crossAxisSpacing: NileSpacing.sm,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => ProductCard(product: sorted[i]),
                );
              },
              loading: () => const NileLoadingState(message: 'Loading products…'),
              error: (e, _) => NileErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(productsProvider(_search)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _sortProducts(List<Product> list) {
    switch (_sort) {
      case 'price_asc':
        list.sort((a, b) {
          final pa = a.variants.isNotEmpty ? a.variants.first.price : 0.0;
          final pb = b.variants.isNotEmpty ? b.variants.first.price : 0.0;
          return pa.compareTo(pb);
        });
        break;
      case 'price_desc':
        list.sort((a, b) {
          final pa = a.variants.isNotEmpty ? a.variants.first.price : 0.0;
          final pb = b.variants.isNotEmpty ? b.variants.first.price : 0.0;
          return pb.compareTo(pa);
        });
        break;
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }
}
