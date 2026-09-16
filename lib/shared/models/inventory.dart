/// Nile Tropical - Inventory Models
/// Copyright © Hon. Dr. Betty Udongo Pacutho

enum StockMovementType {
  purchase,
  sale,
  return_,
  damage,
  expiry,
  adjustment,
  transfer,
  opening,
}

extension StockMovementTypeX on StockMovementType {
  String get label {
    switch (this) {
      case StockMovementType.purchase:
        return 'Purchase';
      case StockMovementType.sale:
        return 'Sale';
      case StockMovementType.return_:
        return 'Return';
      case StockMovementType.damage:
        return 'Damage';
      case StockMovementType.expiry:
        return 'Expiry';
      case StockMovementType.adjustment:
        return 'Adjustment';
      case StockMovementType.transfer:
        return 'Transfer';
      case StockMovementType.opening:
        return 'Opening Balance';
    }
  }

  bool get increasesStock =>
      this == StockMovementType.purchase ||
      this == StockMovementType.return_ ||
      this == StockMovementType.opening ||
      this == StockMovementType.adjustment;
}

class Batch {
  final String id;
  final String productVariantId;
  final String batchNumber;
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final int quantity;
  final String? notes;
  final DateTime createdAt;

  const Batch({
    required this.id,
    required this.productVariantId,
    required this.batchNumber,
    this.manufacturingDate,
    this.expiryDate,
    required this.quantity,
    this.notes,
    required this.createdAt,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get expiresSoon {
    if (expiryDate == null) return false;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 30;
  }

  int? get daysToExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id'] as String,
      productVariantId: json['product_variant_id'] as String,
      batchNumber: json['batch_number'] as String,
      manufacturingDate: json['manufacturing_date'] != null
          ? DateTime.parse(json['manufacturing_date'] as String)
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class StockMovement {
  final String id;
  final String productVariantId;
  final String? batchId;
  final StockMovementType movementType;
  final int quantity; // can be negative
  final String? reference;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  // Optional joined data
  final String? productName;
  final String? variantName;
  final String? sku;

  const StockMovement({
    required this.id,
    required this.productVariantId,
    this.batchId,
    required this.movementType,
    required this.quantity,
    this.reference,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.productName,
    this.variantName,
    this.sku,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      productVariantId: json['product_variant_id'] as String,
      batchId: json['batch_id'] as String?,
      movementType: _parseMovementType(json['movement_type'] as String),
      quantity: json['quantity'] as int,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      sku: json['sku'] as String?,
    );
  }

  static StockMovementType _parseMovementType(String value) {
    switch (value) {
      case 'purchase':
        return StockMovementType.purchase;
      case 'sale':
        return StockMovementType.sale;
      case 'return':
        return StockMovementType.return_;
      case 'damage':
        return StockMovementType.damage;
      case 'expiry':
        return StockMovementType.expiry;
      case 'adjustment':
        return StockMovementType.adjustment;
      case 'transfer':
        return StockMovementType.transfer;
      case 'opening':
        return StockMovementType.opening;
      default:
        return StockMovementType.adjustment;
    }
  }
}

class InventorySummary {
  final String variantId;
  final String productName;
  final String variantName;
  final String sku;
  final int currentStock;
  final int reorderLevel;
  final bool isLowStock;
  final bool hasExpiredBatches;
  final bool hasExpiringSoon;

  const InventorySummary({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.sku,
    required this.currentStock,
    required this.reorderLevel,
    required this.isLowStock,
    this.hasExpiredBatches = false,
    this.hasExpiringSoon = false,
  });
}
