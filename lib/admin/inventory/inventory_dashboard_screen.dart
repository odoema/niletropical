/// Nile Tropical - Inventory Dashboard (Admin)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/inventory.dart';
import '../../shared/services/inventory_service.dart';

final lowStockProvider = FutureProvider<List<InventorySummary>>((ref) async {
  return InventoryService.getLowStockItems();
});

final recentMovementsProvider = FutureProvider<List<StockMovement>>((ref) async {
  return InventoryService.getRecentMovements();
});

final expiringBatchesProvider = FutureProvider<List<Batch>>((ref) async {
  return InventoryService.getExpiringBatches();
});

class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockProvider);
    final movementsAsync = ref.watch(recentMovementsProvider);
    final batchesAsync = ref.watch(expiringBatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(lowStockProvider);
              ref.invalidate(recentMovementsProvider);
              ref.invalidate(expiringBatchesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lowStockProvider);
          ref.invalidate(recentMovementsProvider);
          ref.invalidate(expiringBatchesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Low Stock',
                    value: lowStockAsync.when(
                      data: (list) => '${list.length}',
                      loading: () => '–',
                      error: (_, __) => '–',
                    ),
                    color: NileColors.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Expiring',
                    value: batchesAsync.when(
                      data: (list) => '${list.length}',
                      loading: () => '–',
                      error: (_, __) => '–',
                    ),
                    color: NileColors.error,
                    icon: Icons.event_busy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Low Stock Section
            const Text(
              'Low Stock Alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            lowStockAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('All products are above reorder level.'),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((item) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: NileColors.warning.withOpacity(0.15),
                                child: const Icon(Icons.inventory_2,
                                    color: NileColors.warning),
                              ),
                              title: Text(item.productName),
                              subtitle: Text(
                                  '${item.variantName} • SKU: ${item.sku}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.currentStock}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: NileColors.error,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Reorder: ${item.reorderLevel}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 28),

            // Expiring Batches
            const Text(
              'Expiring / Expired Batches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            batchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (batches) {
                if (batches.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No batches expiring in the next 30 days.'),
                    ),
                  );
                }
                return Column(
                  children: batches.map((b) {
                    final expired = b.isExpired;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (expired
                                  ? NileColors.error
                                  : NileColors.warning)
                              .withOpacity(0.15),
                          child: Icon(
                            expired ? Icons.dangerous : Icons.schedule,
                            color: expired ? NileColors.error : NileColors.warning,
                          ),
                        ),
                        title: Text(b.batchNumber),
                        subtitle: Text(
                          expired
                              ? 'EXPIRED'
                              : 'Expires in ${b.daysToExpiry} days',
                          style: TextStyle(
                            color: expired ? NileColors.error : NileColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text('Qty: ${b.quantity}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 28),

            // Recent Movements
            const Text(
              'Recent Stock Movements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            movementsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (movements) {
                if (movements.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No stock movements yet.'),
                    ),
                  );
                }
                return Column(
                  children: movements.map((m) {
                    final isIn = m.quantity > 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isIn
                                  ? NileColors.success
                                  : NileColors.error)
                              .withOpacity(0.12),
                          child: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIn ? NileColors.success : NileColors.error,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          m.productName ?? m.productVariantId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${m.movementType.label}'
                          '${m.reference != null ? ' • ${m.reference}' : ''}',
                        ),
                        trailing: Text(
                          '${isIn ? '+' : ''}${m.quantity}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIn ? NileColors.success : NileColors.error,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: NileColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
