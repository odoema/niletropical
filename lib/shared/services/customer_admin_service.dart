import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff-only customer admin operations.
/// Relies on existing RLS (is_staff / has_role).
class CustomerAdminService {
  CustomerAdminService(this._client);

  final SupabaseClient _client;

  /// List customers with optional search (name / phone / email).
  Future<List<Map<String, dynamic>>> listCustomers({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final selectCols =
        'id, full_name, phone, email, preferred_area, status, created_at, updated_at';

    // Build filter first, then order/range (Postgrest type chain).
    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      final rows = await _client
          .from('customers')
          .select(selectCols)
          .or('full_name.ilike.$term,phone.ilike.$term,email.ilike.$term')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(rows);
    }

    final rows = await _client
        .from('customers')
        .select(selectCols)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Single customer + addresses + recent orders.
  Future<Map<String, dynamic>?> getCustomerDetail(String customerId) async {
    final customer = await _client
        .from('customers')
        .select(
          'id, full_name, phone, email, preferred_area, status, user_id, created_at, updated_at',
        )
        .eq('id', customerId)
        .maybeSingle();

    if (customer == null) return null;

    final addresses = await _client
        .from('customer_addresses')
        .select(
          'id, country, district, city, area, address_line, landmark, delivery_instructions, is_default, created_at',
        )
        .eq('customer_id', customerId)
        .order('is_default', ascending: false);

    final orders = await _client
        .from('orders')
        .select(
          'id, order_number, status, payment_status, payment_method, total, currency, created_at',
        )
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(30);

    return {
      ...customer,
      'addresses': addresses,
      'orders': orders,
    };
  }

  /// Soft status change (active / inactive / blocked).
  Future<void> updateCustomerStatus(String customerId, String status) async {
    assert(
      ['active', 'inactive', 'blocked'].contains(status),
      'Invalid customer status',
    );
    await _client.from('customers').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', customerId);
  }
}
