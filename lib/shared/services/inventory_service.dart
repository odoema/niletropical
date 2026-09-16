/// Nile Tropical - Inventory Service
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import '../../core/config/env.dart';
import '../models/inventory.dart';
import '../models/product.dart';
import 'supabase_service.dart';

/// Thrown when adjust_stock() rejects a movement because it would take
/// stock negative. Callers (e.g. checkout) should catch this specifically
/// and show "out of stock" rather than a generic error.
class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);
  @override
  String toString() => message;
}

class InventoryService {
  /// Record a stock movement and update variant stock atomically via the
  /// `adjust_stock` Postgres function (supabase/migrations/013_functions.sql).
  /// This replaces the previous client-side read→calculate→write, which
  /// could oversell under concurrent requests — see AUDIT.md.
  static Future<int> recordMovement({
    required String productVariantId,
    String? batchId,
    required StockMovementType type,
    required int quantity,
    String? reference,
    String? notes,
    String? createdBy,
  }) async {
    try {
      final result = await SupabaseService.client.rpc('adjust_stock', params: {
        'p_variant_id': productVariantId,
        'p_quantity': quantity,
        'p_movement_type': type.name == 'return_' ? 'return' : type.name,
        'p_reference': reference,
        'p_notes': notes,
        'p_batch_id': batchId,
        'p_created_by': createdBy,
      });

      // adjust_stock returns a single-row table with new_stock_quantity.
      final row = (result as List).first as Map<String, dynamic>;
      return row['new_stock_quantity'] as int;
    } on Object catch (e) {
      if (e.toString().contains('INSUFFICIENT_STOCK')) {
        throw InsufficientStockException(
          'Not enough stock available for this item.',
        );
      }
      rethrow;
    }
  }

  /// Get low stock items
  static Future<List<InventorySummary>> getLowStockItems() async {
    try {
      final response = await SupabaseService.client
          .from('product_variants')
          .select('''
            id,
            name,
            sku,
            stock_quantity,
            reorder_level,
            products ( name )
          ''')
          .eq('is_active', true);

      final List<InventorySummary> result = [];
      for (final row in response as List) {
        final stock = row['stock_quantity'] as int? ?? 0;
        final reorder = row['reorder_level'] as int? ?? 5;
        if (stock <= reorder) {
          result.add(InventorySummary(
            variantId: row['id'] as String,
            productName: (row['products'] as Map?)?['name'] as String? ?? '',
            variantName: row['name'] as String? ?? '',
            sku: row['sku'] as String? ?? '',
            currentStock: stock,
            reorderLevel: reorder,
            isLowStock: true,
          ));
        }
      }
      return result;
    } catch (_) {
      if (!Env.isDevelopment) rethrow;
      return _mockLowStock;
    }
  }

  /// Get recent stock movements
  static Future<List<StockMovement>> getRecentMovements({int limit = 50}) async {
    try {
      final response = await SupabaseService.client
          .from('stock_movements')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((j) => StockMovement.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      if (!Env.isDevelopment) rethrow;
      return _mockMovements;
    }
  }

  /// Get batches that are expired or expiring soon
  static Future<List<Batch>> getExpiringBatches({int withinDays = 30}) async {
    try {
      final response = await SupabaseService.client
          .from('batches')
          .select('*')
          .not('expiry_date', 'is', null)
          .order('expiry_date');

      final now = DateTime.now();
      final cutoff = now.add(Duration(days: withinDays));

      return (response as List)
          .map((j) => Batch.fromJson(j as Map<String, dynamic>))
          .where((b) =>
              b.expiryDate != null &&
              (b.expiryDate!.isBefore(now) || b.expiryDate!.isBefore(cutoff)))
          .toList();
    } catch (_) {
      if (!Env.isDevelopment) rethrow;
      return _mockBatches;
    }
  }

  // ---------- Mock data for development ----------
  static final _mockLowStock = [
    const InventorySummary(
      variantId: 'v4',
      productName: 'Nile Liquid Hand Sanitizer',
      variantName: '500ml',
      sku: 'NHS-500',
      currentStock: 8,
      reorderLevel: 20,
      isLowStock: true,
    ),
    const InventorySummary(
      variantId: 'v7',
      productName: 'Hibiscus Tea',
      variantName: '150g',
      sku: 'HT-150',
      currentStock: 4,
      reorderLevel: 10,
      isLowStock: true,
    ),
  ];

  static final _mockMovements = [
    StockMovement(
      id: 'm1',
      productVariantId: 'v1',
      movementType: StockMovementType.sale,
      quantity: -2,
      reference: 'NTI-2026-000125',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      productName: 'E.C.O Shea Butter',
      variantName: '250g',
      sku: 'ECO-SB-250',
    ),
    StockMovement(
      id: 'm2',
      productVariantId: 'v4',
      movementType: StockMovementType.sale,
      quantity: -5,
      reference: 'NTI-2026-000124',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      productName: 'Nile Liquid Hand Sanitizer',
      variantName: '500ml',
      sku: 'NHS-500',
    ),
    StockMovement(
      id: 'm3',
      productVariantId: 'v1',
      movementType: StockMovementType.purchase,
      quantity: 50,
      reference: 'PO-2026-018',
      notes: 'New stock received',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      productName: 'E.C.O Shea Butter',
      variantName: '250g',
      sku: 'ECO-SB-250',
    ),
  ];

  static final _mockBatches = [
    Batch(
      id: 'b1',
      productVariantId: 'v1',
      batchNumber: 'BATCH-2025-A12',
      manufacturingDate: DateTime(2025, 6, 15),
      expiryDate: DateTime.now().add(const Duration(days: 18)),
      quantity: 30,
      createdAt: DateTime(2025, 6, 20),
    ),
    Batch(
      id: 'b2',
      productVariantId: 'v7',
      batchNumber: 'BATCH-2024-H03',
      manufacturingDate: DateTime(2024, 11, 1),
      expiryDate: DateTime.now().subtract(const Duration(days: 5)),
      quantity: 4,
      createdAt: DateTime(2024, 11, 5),
    ),
  ];
}
