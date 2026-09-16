/// Nile Tropical - Delivery Models
/// Copyright © Hon. Dr. Betty Udongo Pacutho

enum DeliveryPartnerType { bus, taxi, courierCompany, boda, other }

extension DeliveryPartnerTypeX on DeliveryPartnerType {
  String get label {
    switch (this) {
      case DeliveryPartnerType.bus:
        return 'Bus';
      case DeliveryPartnerType.taxi:
        return 'Taxi';
      case DeliveryPartnerType.courierCompany:
        return 'Courier Company';
      case DeliveryPartnerType.boda:
        return 'Boda Boda';
      case DeliveryPartnerType.other:
        return 'Other';
    }
  }
}

class DeliveryZone {
  final String id;
  final String name;
  final double deliveryFee;
  final int? estimatedDays;
  final bool isActive;
  final String? notes;

  const DeliveryZone({
    required this.id,
    required this.name,
    required this.deliveryFee,
    this.estimatedDays,
    this.isActive = true,
    this.notes,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] as String,
      name: json['name'] as String,
      deliveryFee: ((json['delivery_fee'] ?? json['fee'] ?? 0) as num).toDouble(),
      estimatedDays: json['estimated_days'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
    );
  }
}

class DeliveryPartner {
  final String id;
  final String name;
  final DeliveryPartnerType type;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? terminal;
  final List<String> routes;
  final bool isActive;

  const DeliveryPartner({
    required this.id,
    required this.name,
    required this.type,
    this.contactPerson,
    this.phone,
    this.email,
    this.terminal,
    this.routes = const [],
    this.isActive = true,
  });

  factory DeliveryPartner.fromJson(Map<String, dynamic> json) {
    return DeliveryPartner(
      id: json['id'] as String,
      name: json['name'] as String,
      type: _parseType(json['type'] as String?),
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      terminal: json['terminal'] as String?,
      routes: (json['routes'] as List<dynamic>?)?.cast<String>() ?? [],
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static DeliveryPartnerType _parseType(String? value) {
    switch (value) {
      case 'bus':
        return DeliveryPartnerType.bus;
      case 'taxi':
        return DeliveryPartnerType.taxi;
      case 'courier_company':
        return DeliveryPartnerType.courierCompany;
      case 'boda':
        return DeliveryPartnerType.boda;
      default:
        return DeliveryPartnerType.other;
    }
  }
}

class Courier {
  final String id;
  final String fullName;
  final String phone;
  final String? idNumber;
  final String? vehicleType;
  final String? registrationNumber;
  final String? operatingArea;
  final double? commissionRate;
  final bool isActive;

  const Courier({
    required this.id,
    required this.fullName,
    required this.phone,
    this.idNumber,
    this.vehicleType,
    this.registrationNumber,
    this.operatingArea,
    this.commissionRate,
    this.isActive = true,
  });

  factory Courier.fromJson(Map<String, dynamic> json) {
    return Courier(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      idNumber: json['id_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      registrationNumber: json['registration_number'] as String?,
      operatingArea: json['operating_area'] as String?,
      commissionRate: (json['commission_rate'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class Shipment {
  final String id;
  final String orderId;
  final String? deliveryPartnerId;
  final String? courierId;
  final String? trackingReference;
  final String status;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  const Shipment({
    required this.id,
    required this.orderId,
    this.deliveryPartnerId,
    this.courierId,
    this.trackingReference,
    required this.status,
    this.dispatchedAt,
    this.deliveredAt,
    required this.createdAt,
  });
}
