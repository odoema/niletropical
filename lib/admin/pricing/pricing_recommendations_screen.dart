import 'package:flutter/material.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/errors/error_reporter.dart';
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
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        stackTrace: stack,
        source: 'admin_pricing',
        action: 'load_recommendations',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorReporter.friendlyMessage(e);
      });
    }
  }

  String _normaliseStatus(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value == 'pending_approval' || value == 'pending_review' || value == 'pending') {
      return 'pending';
    }
    return value;
  }

  List<Map<String, dynamic>> get _visible => _filter == 'all'
      ? _rows
      : _rows.where((r) => _normaliseStatus(r['status']?.toString()) == _filter).toList();

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    try {
      await SupabaseService.client.from('pricing_recommendations').update({'status': status}).eq('id', row['id']);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recommendation ' + (status == 'approved' ? 'approved.' : 'rejected.'))),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorReporter.friendlyMessage(e)), backgroundColor: NileColors.error),
      );
    }
  }

  Future<void> _applyPrice(Map<String, dynamic> row) async {
    final recommendationId = row['id']?.toString();
    if (recommendationId == null || recommendationId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This recommendation has no valid ID.')),
      );
      return;
    }

    final proposed = row['recommended_price'] ?? row['proposed_price'] ?? row['suggested_price'];
    final price = proposed is num
        ? proposed.toDouble()
        : double.tryParse(proposed?.toString().replaceAll(',', '') ?? '');

    if (price == null || price <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The recommendation does not contain a valid price.')),
      );
      return;
    }

    final product = (row['product_name'] ?? row['product_variant_name'] ?? 'this product').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply price to product?'),
        content: Text(
          'This will change the live selling price of ' + product +
          ' to UGX ' + price.toStringAsFixed(0) +
          ' and mark the recommendation as approved. The old and new prices will be recorded in the audit log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Apply price'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client.rpc(
        'apply_pricing_recommendation',
        params: {'p_recommendation_id': recommendationId},
      );

      await _load();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Live price updated to UGX ' + price.toStringAsFixed(0) + ' and recorded in the audit log.'),
          backgroundColor: NileColors.success,
        ),
      );
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        stackTrace: stack,
        source: 'admin_pricing',
        action: 'apply_price',
        context: {'recommendation_id': recommendationId},
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorReporter.friendlyMessage(e)),
          backgroundColor: NileColors.error,
        ),
      );
    }
  }

  Future<void> _editRecommendation(Map<String, dynamic> row) async {
    final priceController = TextEditingController(
      text: (row['recommended_price'] ?? row['proposed_price'] ?? row['suggested_price'] ?? '').toString(),
    );
    final reasonController = TextEditingController(
      text: (row['reason'] ?? row['rationale'] ?? row['explanation'] ?? '').toString(),
    );
    String status = row['status']?.toString() ?? 'pending_approval';
    if (status != 'pending_approval' && status != 'approved' && status != 'rejected') {
      status = 'pending_approval';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Recommendation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (row['product_name'] ?? row['product_variant_name'] ?? row['product_variant_id'] ?? 'Product').toString(),
                  style: NileTypography.titleMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Recommended price (UGX)',
                    prefixText: 'UGX ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'pending_approval', child: Text('Pending approval')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Recommendation rationale',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () {
                if (priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a recommended price.')));
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      priceController.dispose();
      reasonController.dispose();
      return;
    }

    final price = num.tryParse(priceController.text.replaceAll(',', '').trim());
    final reason = reasonController.text.trim();
    if (price == null || price <= 0) {
      priceController.dispose();
      reasonController.dispose();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid positive price.')));
      return;
    }

    try {
      final update = <String, dynamic>{
        'status': status,
        'recommended_price': price,
      };

      // The production table uses a rationale/explanation field rather than
      // `reason`. Only send the key that actually exists on this row, so an
      // edit cannot fail with PostgREST's PGRST204 schema-cache error.
      const rationaleKeys = ['reason', 'rationale', 'explanation'];
      final rationaleKey = rationaleKeys.cast<String?>().firstWhere(
        (key) => row.containsKey(key),
        orElse: () => null,
      );
      if (rationaleKey != null) {
        update[rationaleKey] = reason;
      }

      await SupabaseService.client
          .from('pricing_recommendations')
          .update(update)
          .eq('id', row['id']);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recommendation updated successfully.')));
    } catch (e, stack) {
      ErrorReporter.report(
        e,
        stackTrace: stack,
        source: 'admin_pricing',
        action: 'edit_recommendation',
        context: {'recommendation_id': row['id']},
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorReporter.friendlyMessage(e)), backgroundColor: NileColors.error),
      );
    } finally {
      priceController.dispose();
      reasonController.dispose();
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
                  onApprove: () => _applyPrice(_visible[i]),
                  onReject: () => _setStatus(_visible[i], 'rejected'),
                  onEdit: () => _editRecommendation(_visible[i]),
                  onApplyPrice: () => _applyPrice(_visible[i]),
                ),
              )),
        ]),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.row,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onApplyPrice,
  });
  final Map<String, dynamic> row;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onApplyPrice;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending_approval';
    final isPending = status == 'pending_approval' || status == 'pending' || status == 'pending_review';
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
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
          if (isPending)
            FilledButton.icon(
              onPressed: onApplyPrice,
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Approve & Apply'),
            ),
          if (status != 'rejected' && status != 'approved')
            OutlinedButton.icon(onPressed: onReject, icon: const Icon(Icons.close), label: const Text('Reject')),
        ],
      ),
    ]));
  }
}
