import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class PricingRecommendationsScreen extends StatefulWidget {
  const PricingRecommendationsScreen({super.key});
  @override
  State<PricingRecommendationsScreen> createState() => _PricingRecommendationsScreenState();
}

class _PricingRecommendationsScreenState extends State<PricingRecommendationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() { _loading = false; _error = 'Supabase is not configured.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await SupabaseService.client.from('pricing_recommendations').select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { _rows = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _visible => _filter == 'all'
      ? _rows
      : _rows.where((r) => (r['status']?.toString() ?? 'pending') == _filter).toList();

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    try {
      await SupabaseService.client.from('pricing_recommendations').update({'status': status}).eq('id', row['id']);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update recommendation: ' + e.toString()), backgroundColor: NileColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing Recommendations'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      body: _loading ? const NileLoadingState() : _error != null ? NileErrorState(message: _error!, onRetry: _load) :
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 8, children: [
              for (final s in ['all', 'pending', 'approved', 'rejected'])
                ChoiceChip(label: Text(s[0].toUpperCase() + s.substring(1)), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
            ]),
          ),
          Expanded(child: _visible.isEmpty
            ? const Center(child: Text('No pricing recommendations found.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _RecommendationCard(
                  row: _visible[i],
                  onApprove: () => _setStatus(_visible[i], 'approved'),
                  onReject: () => _setStatus(_visible[i], 'rejected'),
                ),
              )),
        ]),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.row, required this.onApprove, required this.onReject});
  final Map<String, dynamic> row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending';
    final product = row['product_name'] ?? row['product_variant_name'] ?? row['product_variant_id'] ?? 'Product';
    final proposed = row['recommended_price'] ?? row['proposed_price'] ?? row['suggested_price'];
    final current = row['current_price'];
    final reason = row['reason'] ?? row['rationale'] ?? row['explanation'];
    return NileCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(product.toString(), style: NileTypography.titleMedium)),
        Chip(label: Text(status), visualDensity: VisualDensity.compact),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 18, runSpacing: 6, children: [
        if (current != null) Text('Current: UGX ' + current.toString()),
        if (proposed != null) Text('Proposed: UGX ' + proposed.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      if (reason != null) ...[const SizedBox(height: 8), Text(reason.toString(), style: NileTypography.bodySmall)],
      if (status == 'pending') ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: onApprove, icon: const Icon(Icons.check), label: const Text('Approve')),
          OutlinedButton.icon(onPressed: onReject, icon: const Icon(Icons.close), label: const Text('Reject')),
        ]),
      ],
    ]));
  }
}
