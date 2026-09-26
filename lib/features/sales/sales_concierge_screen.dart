import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/models/product.dart';
import '../../shared/providers/cart_provider.dart';
import '../../shared/providers/product_provider.dart';

class SalesConciergeScreen extends ConsumerStatefulWidget {
  const SalesConciergeScreen({super.key});
  @override ConsumerState<SalesConciergeScreen> createState() => _SalesConciergeScreenState();
}

class _SalesConciergeScreenState extends ConsumerState<SalesConciergeScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [const _Msg('Hello! Tell me what you need, your budget, or what problem you want to solve. I will search the current Nile Tropical catalogue and suggest available products.', false)];

  @override void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  void _ask([String? preset]) {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    setState(() => _messages.add(_Msg(q, true)));
    final products = ref.read(productsProvider(null)).valueOrNull ?? const <Product>[];
    final result = _find(q, products);
    setState(() => _messages.add(_Msg(result.$1, false, result.$2)));
  }

  String? _sheaAnswer(String q) {
    final shea = q.contains('shea') || q.contains('vitellaria') ||
        q.contains('butyrospermum') || q.contains('shea butter');
    if (!shea) return null;

    if (q.contains('what') || q.contains('benefit') || q.contains('good for') ||
        q.contains('why') || q.contains('help')) {
      return 'Shea butter is a plant fat from the kernels of the shea tree (Vitellaria paradoxa). '
          'For skincare, its main established role is as an emollient: it helps soften dry skin and supports the skin barrier. '
          'It contains mainly stearic and oleic fatty acids plus smaller amounts of unsaponifiable compounds such as tocopherols, sterols and triterpenes. '
          'Research reviews describe moisturizing, barrier-supporting, antioxidant and anti-inflammatory potential, but evidence varies by product and condition. '
          'It should not be presented as a cure for eczema, infections, scars or other diseases.';
    }

    if (q.contains('skin') || q.contains('dry') || q.contains('moistur') ||
        q.contains('face') || q.contains('body')) {
      return 'For dry skin, shea butter works mainly as an emollient and barrier-supporting moisturizer. '
          'Apply a small amount to clean, slightly damp skin and massage gently. '
          'For facial use, start with a small area because individual skin types differ. '
          'If irritation occurs, stop using it. Persistent or severe skin disease should be assessed by a clinician.';
    }

    if (q.contains('hair') || q.contains('scalp')) {
      return 'Shea butter is commonly used in hair and scalp products because its lipid-rich texture can condition and reduce the feeling of dryness. '
          'It is a cosmetic conditioner, not a proven treatment for hair loss or scalp disease. '
          'Use a small amount and adjust to your hair type to avoid heaviness or buildup.';
    }

    if (q.contains('baby') || q.contains('infant')) {
      return 'Shea butter is used in many baby-care products as a skin-conditioning ingredient. '
          'Choose a properly formulated product and patch-test when appropriate. '
          'For a baby with a persistent rash, broken skin or suspected eczema, seek medical advice rather than relying on a cosmetic product alone.';
    }

    if (q.contains('sun') || q.contains('spf') || q.contains('sunscreen')) {
      return 'Shea butter contains compounds that have shown UV-related activity in laboratory and formulation research, but ordinary shea butter is not a reliable sunscreen. '
          'For sun protection, use a properly tested broad-spectrum sunscreen with a stated SPF.';
    }

    if (q.contains('allerg') || q.contains('safe') || q.contains('side effect')) {
      return 'Shea-derived cosmetic ingredients have a good safety record when properly formulated and non-sensitizing, but no ingredient is right for everyone. '
          'Patch-test if you are concerned, stop if you develop irritation or allergy symptoms, and seek medical care for a significant reaction.';
    }

    if (q.contains('eat') || q.contains('food') || q.contains('cook')) {
      return 'Shea butter can be used as a food fat in appropriate food-grade products, but a cosmetic product should not be assumed to be edible. '
          'For eating or cooking, use a product specifically labelled and manufactured for food use.';
    }

    if (q.contains('raw') || q.contains('refined') || q.contains('unrefined')) {
      return 'Unrefined shea butter generally retains more of the minor unsaponifiable compounds and its characteristic colour and aroma. '
          'Refining can reduce some minor components while improving odour, colour and oxidative stability. '
          'Quality depends on sourcing, processing, storage and formulation.';
    }

    return 'Shea butter is a plant fat from Vitellaria paradoxa. It is rich in stearic and oleic fatty acids and is widely used as an emollient and skin-conditioning ingredient. '
        'Ask me about benefits, dry skin, hair, babies, sun protection, safety, or refined versus unrefined shea.';
  }

  (String, List<Product>) _find(String query, List<Product> products) {
    final q = query.toLowerCase();
    final sheaAnswer = _sheaAnswer(q);
    final budget = _budget(q);
    if (sheaAnswer != null && (q.contains('what') || q.contains('benefit') || q.contains('good for') || q.contains('why') || q.contains('help') || q.contains('skin') || q.contains('dry') || q.contains('hair') || q.contains('scalp') || q.contains('baby') || q.contains('safe') || q.contains('allerg') || q.contains('raw') || q.contains('refined') || q.contains('sun') || q.contains('spf') || q.contains('eat') || q.contains('food'))) {
      return (sheaAnswer, _sheaProducts(products));
    }
    final words = q.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(RegExp(r'\s+')).where((x) => x.length > 2).toSet();
    final scored = <_Score>[];
    for (final p in products) {
      final stock = p.variants.where((v) => v.isActive && v.inStock).toList();
      if (stock.isEmpty) continue;
      final text = [p.name, p.shortDescription ?? '', p.fullDescription ?? '', p.benefits ?? '', p.ingredients ?? '', p.brand].join(' ').toLowerCase();
      var score = 0;
      for (final w in words) { if (text.contains(w)) score += 3; }
      if (q.contains('sanit') && text.contains('sanit')) score += 10;
      if (q.contains('mosquito') && text.contains('mosquito')) score += 10;
      if ((q.contains('skin') || q.contains('dry') || q.contains('moistur')) && RegExp(r'shea|skin|moistur').hasMatch(text)) score += 8;
      if (q.contains('tea') && text.contains('tea')) score += 10;
      if (q.contains('gift') && p.isFeatured) score += 3;
      if (p.isBestseller) score += 1;
      final cheapest = stock.map((v) => v.price).reduce((a,b) => a < b ? a : b);
      if (budget != null) score += cheapest <= budget ? 5 : -6;
      if (score > 0) scored.add(_Score(p, score));
    }
    scored.sort((a,b) => b.score.compareTo(a.score));
    var matches = scored.take(4).map((x) => x.product).toList();
    if (budget != null) matches = matches.where((p) => p.variants.any((v) => v.isActive && v.inStock && v.price <= budget)).toList();
    if (matches.isEmpty) {
      matches = products.where((p) => p.variants.any((v) => v.isActive && v.inStock && (budget == null || v.price <= budget))).take(4).toList();
      return ('I could not find an exact match in the current catalogue. Here are available options' + (budget == null ? '.' : ' within your budget.'), matches);
    }
    return (budget == null ? 'These are the closest in-stock matches from the current catalogue.' : 'I found these in-stock options within your UGX ' + _money(budget) + ' budget.', matches);
  }

  List<Product> _sheaProducts(List<Product> products) {
    final matches = products.where((p) {
      final text = [p.name, p.shortDescription ?? '', p.fullDescription ?? '',
        p.benefits ?? '', p.ingredients ?? '', p.brand].join(' ').toLowerCase();
      return text.contains('shea');
    }).where((p) => p.variants.any((v) => v.isActive && v.inStock)).take(4).toList();
    return matches;
  }

  double? _budget(String q) {
    final m = RegExp(r'(?:under|below|less than|budget(?: of)?|within)\s*(?:ugx|shs|/=)?\s*([0-9][0-9,]*)').firstMatch(q);
    return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', ''));
  }
  String _money(double value) => value.round().toString().replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',');

  void _add(Product p) {
    final v = p.variants.where((x) => x.isActive && x.inStock).firstOrNull;
    if (v == null) return;
    ref.read(cartProvider.notifier).addItem(p, v);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.name + ' added to cart')));
  }

  @override Widget build(BuildContext context) {
    final count = ref.watch(cartItemCountProvider);
    return Scaffold(
      appBar: NileAppBar(title: 'Shopping Concierge', actions: [IconButton(onPressed: () => context.push('/cart'), icon: Badge(isLabelVisible: count > 0, label: Text(count.toString()), child: const Icon(Icons.shopping_bag_outlined)))]),
      body: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(16), color: NileColors.primaryContainer, child: const Row(children: [CircleAvatar(backgroundColor: NileColors.primary, child: Icon(Icons.auto_awesome, color: Colors.white)), SizedBox(width: 12), Expanded(child: Text('Try: dry skin under 20,000; sanitizer; mosquito products; or gift ideas.', style: TextStyle(fontWeight: FontWeight.w600)))])),
        Expanded(child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
          ..._messages.map((m) => _Bubble(m, _add)),
          if (_messages.length == 1) Wrap(spacing: 8, children: [
            ActionChip(label: const Text('Dry skin'), onPressed: () => _ask('I need something for dry skin')),
            ActionChip(label: const Text('Under UGX 10,000'), onPressed: () => _ask('Show me products under UGX 10,000')),
            ActionChip(label: const Text('Sanitizer'), onPressed: () => _ask('I need a sanitizer')),
          ]),
        ])),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: _input, onSubmitted: (_) => _ask(), decoration: const InputDecoration(hintText: 'What are you looking for?', prefixIcon: Icon(Icons.search)))), const SizedBox(width: 8), IconButton.filled(onPressed: _ask, icon: const Icon(Icons.send))]))),
      ]),
    );
  }
}

class _Msg { final String text; final bool customer; final List<Product> products; const _Msg(this.text, this.customer, [this.products = const []]); }
class _Score { final Product product; final int score; const _Score(this.product, this.score); }

class _Bubble extends StatelessWidget {
  final _Msg msg; final void Function(Product) onAdd;
  const _Bubble(this.msg, this.onAdd);
  @override Widget build(BuildContext context) => Align(alignment: msg.customer ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 720), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: msg.customer ? NileColors.primary : NileColors.surface, borderRadius: BorderRadius.circular(16), border: msg.customer ? null : Border.all(color: NileColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(msg.text, style: TextStyle(color: msg.customer ? Colors.white : NileColors.textPrimary, height: 1.4)), ...msg.products.map((p) => _ProductPick(p, onAdd))])));
}

class _ProductPick extends StatelessWidget {
  final Product product; final void Function(Product) onAdd;
  const _ProductPick(this.product, this.onAdd);
  @override Widget build(BuildContext context) {
    final stock = product.variants.where((v) => v.isActive && v.inStock).toList();
    final cheapest = stock.isEmpty ? null : stock.map((v) => v.price).reduce((a,b) => a < b ? a : b);
    return Card(margin: const EdgeInsets.only(top: 8), child: ListTile(leading: SizedBox(width: 48, height: 48, child: product.mainImageUrl == null ? const Icon(Icons.inventory_2_outlined) : Image.network(product.mainImageUrl!, fit: BoxFit.contain)), title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text((cheapest == null ? '' : 'From UGX ' + cheapest.round().toString()) + (product.shortDescription == null ? '' : ' · ' + product.shortDescription!), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: stock.isEmpty ? null : () => onAdd(product), icon: const Icon(Icons.add_shopping_cart_outlined, color: NileColors.primary)), onTap: () => context.push('/product/' + product.slug)));
  }
}