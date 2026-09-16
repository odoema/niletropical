/// Live delivery_zones / partners / couriers. Mocks only when unconfigured.
import '../models/delivery.dart';
import '../../core/config/env.dart';
import 'supabase_service.dart';

class DeliveryService {
  static Future<List<DeliveryZone>> getZones() async {
    if (!Env.isConfigured) return _devZones;
    final rows = await SupabaseService.client
        .from('delivery_zones')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows)
        .map(DeliveryZone.fromJson)
        .toList();
  }

  static Future<List<DeliveryPartner>> getPartners() async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseService.client
        .from('delivery_partners')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows)
        .map(DeliveryPartner.fromJson)
        .toList();
  }

  static Future<List<Courier>> getCouriers() async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseService.client
        .from('couriers')
        .select()
        .eq('is_active', true)
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows).map(Courier.fromJson).toList();
  }

  static Future<String> createZone({
    required String name,
    required double fee,
    int? estimatedDays,
    String? notes,
  }) async {
    if (!Env.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    // Param names match the rewritten 019_admin_rpcs.sql signature:
    // (p_name, p_delivery_fee, p_estimated_days, p_notes). The base
    // schema has no `districts` column on delivery_zones — legacy
    // callers that packed a list of districts should stringify them
    // into `notes` instead.
    final id = await SupabaseService.client.rpc(
      'admin_create_delivery_zone',
      params: {
        'p_name': name,
        'p_delivery_fee': fee,
        if (estimatedDays != null) 'p_estimated_days': estimatedDays,
        if (notes != null) 'p_notes': notes,
      },
    );
    return id.toString();
  }

  static Future<String> createCourier({
    required String fullName,
    required String phone,
    String? vehicleType,
    String? operatingArea,
    double? commissionRate,
  }) async {
    if (!Env.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    // Param names match the rewritten 019_admin_rpcs.sql signature:
    // (p_full_name, p_phone, p_vehicle_type, p_operating_area,
    // p_commission_rate). Couriers and delivery_partners are joined
    // via shipments, not by a column on couriers — the earlier
    // p_partner_id was writing to a column that never existed.
    final id = await SupabaseService.client.rpc(
      'admin_create_courier',
      params: {
        'p_full_name': fullName,
        'p_phone': phone,
        if (vehicleType != null) 'p_vehicle_type': vehicleType,
        if (operatingArea != null) 'p_operating_area': operatingArea,
        if (commissionRate != null) 'p_commission_rate': commissionRate,
      },
    );
    return id.toString();
  }

  /// Dev-only fallback so checkout can be exercised without a project.
  static const _devZones = [
    DeliveryZone(id: '00000000-0000-0000-0000-000000000001', name: 'Kampala', deliveryFee: 5000, estimatedDays: 1),
    DeliveryZone(id: '00000000-0000-0000-0000-000000000002', name: 'Greater Kampala', deliveryFee: 8000, estimatedDays: 1),
    DeliveryZone(id: '00000000-0000-0000-0000-000000000003', name: 'Upcountry', deliveryFee: 15000, estimatedDays: 3),
  ];
}
