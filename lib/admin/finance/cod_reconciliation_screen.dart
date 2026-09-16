import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/cod_service.dart';

class _Nile {
  static const primary = Color(0xFF233E85);
  static const success = Color(0xFF1F7A4D);
  static const warning = Color(0xFFB7791F);
  static const surface = Color(0xFFF7F8FA);
}

final _codServiceProvider = Provider<CodService>((ref) {
  return CodService(Supabase.instance.client);
});

final _codListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, bool?>((ref, collectedOnly) {
  return ref
      .watch(_codServiceProvider)
      .listCollections(collectedOnly: collectedOnly);
});

final _codSummaryProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) {
  return ref.watch(_codServiceProvider).summary();
});

/// Admin → Finance → COD Reconciliation (Gap #3)
/// Route: /admin/finance/cod
class CodReconciliationScreen extends ConsumerStatefulWidget {
  const CodReconciliationScreen({super.key});

  @override
  ConsumerState<CodReconciliationScreen> createState() =>
      _CodReconciliationScreenState();
}

class _CodReconciliationScreenState
    extends ConsumerState<CodReconciliationScreen> {
  bool? _filter; // null=all, false=outstanding, true=collected

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(_codSummaryProvider);
    final listAsync = ref.watch(_codListProvider(_filter));
    final money = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: _Nile.surface,
      appBar: AppBar(
        backgroundColor: _Nile.primary,
        foregroundColor: Colors.white,
        title: const Text('COD Reconciliation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_codSummaryProvider);
              ref.invalidate(_codListProvider(_filter));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          summaryAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _SummaryTile(
                    label: 'Total due',
                    value: money.format(s['total_due'] ?? 0),
                  ),
                  _SummaryTile(
                    label: 'Collected',
                    value: money.format(s['total_collected'] ?? 0),
                    color: _Nile.success,
                  ),
                  _SummaryTile(
                    label: 'Outstanding',
                    value: money.format(s['outstanding'] ?? 0),
                    color: _Nile.warning,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  selectedColor: _Nile.primary.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _filter = null),
                ),
                ChoiceChip(
                  label: const Text('Outstanding'),
                  selected: _filter == false,
                  selectedColor: _Nile.warning.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _filter = false),
                ),
                ChoiceChip(
                  label: const Text('Collected'),
                  selected: _filter == true,
                  selectedColor: _Nile.success.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _filter = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No COD records'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final order = Map<String, dynamic>.from(
                        row['orders'] as Map? ?? {});
                    final due = (row['amount_due'] as num?)?.toDouble() ?? 0;
                    final collected =
                        (row['amount_collected'] as num?)?.toDouble() ?? 0;
                    final isCollected = row['collected_at'] != null;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        title: Text(
                          order['order_number']?.toString() ??
                              row['order_id']?.toString() ??
                              '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${order['customer_name_snapshot'] ?? ''} · '
                          '${order['customer_phone_snapshot'] ?? ''}\n'
                          'Due ${money.format(due)} · '
                          'Collected ${money.format(collected)}',
                        ),
                        isThreeLine: true,
                        trailing: isCollected
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _Nile.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Collected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _Nile.success,
                                  ),
                                ),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _Nile.primary,
                                ),
                                onPressed: () => _recordDialog(
                                  context,
                                  orderId: row['order_id'] as String,
                                  amountDue: due,
                                ),
                                child: const Text('Record'),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordDialog(
    BuildContext context, {
    required String orderId,
    required double amountDue,
  }) async {
    final amountCtrl =
        TextEditingController(text: amountDue.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record COD collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount collected (UGX)',
              ),
            ),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: 'Confirmation / receipt ref (optional)',
              ),
            ),
            TextField(
              controller: notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _Nile.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await ref.read(_codServiceProvider).recordCollection(
            orderId: orderId,
            amountDue: amountDue,
            amountCollected: amount,
            confirmationReference:
                refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
            notes:
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          );
      ref.invalidate(_codSummaryProvider);
      ref.invalidate(_codListProvider(_filter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('COD collection recorded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color ?? _Nile.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
