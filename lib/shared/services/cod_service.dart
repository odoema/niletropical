import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff / finance COD reconciliation.
class CodService {
  CodService(this._client);

  final SupabaseClient _client;

  static const _select = '''
    id,
    order_id,
    amount_due,
    amount_collected,
    collected_by,
    collected_at,
    confirmation_reference,
    notes,
    orders!inner (
      id,
      order_number,
      status,
      payment_status,
      customer_name_snapshot,
      customer_phone_snapshot,
      total,
      currency,
      created_at
    )
  ''';

  /// List COD collections (optionally filter by collected / uncollected).
  Future<List<Map<String, dynamic>>> listCollections({
    bool? collectedOnly,
    int limit = 100,
  }) async {
    // Apply null-filters BEFORE order/limit so the builder stays filterable.
    if (collectedOnly == true) {
      final rows = await _client
          .from('cod_collections')
          .select(_select)
          .not('collected_at', 'is', null)
          .order('collected_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    }

    if (collectedOnly == false) {
      final rows = await _client
          .from('cod_collections')
          .select(_select)
          .filter('collected_at', 'is', null)
          .order('collected_at', ascending: false, nullsFirst: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    }

    final rows = await _client
        .from('cod_collections')
        .select(_select)
        .order('collected_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Record or update a COD collection (staff/finance only via RLS).
  Future<void> recordCollection({
    required String orderId,
    required double amountDue,
    required double amountCollected,
    String? confirmationReference,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;

    await _client.from('cod_collections').upsert(
      {
        'order_id': orderId,
        'amount_due': amountDue,
        'amount_collected': amountCollected,
        'collected_by': uid,
        'collected_at': DateTime.now().toUtc().toIso8601String(),
        'confirmation_reference': confirmationReference,
        'notes': notes,
      },
      onConflict: 'order_id',
    );

    // Keep order payment_status in sync when fully collected.
    if (amountCollected >= amountDue && amountDue > 0) {
      await _client.from('orders').update({
        'payment_status': 'paid',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
    }
  }

  /// Simple totals for the reconciliation header.
  Future<Map<String, double>> summary() async {
    final rows = await _client
        .from('cod_collections')
        .select('amount_due, amount_collected, collected_at');

    double due = 0;
    double collected = 0;
    double outstanding = 0;

    for (final r in rows) {
      final d = (r['amount_due'] as num?)?.toDouble() ?? 0;
      final c = (r['amount_collected'] as num?)?.toDouble() ?? 0;
      due += d;
      collected += c;
      if (r['collected_at'] == null) {
        outstanding += (d - c).clamp(0, double.infinity);
      }
    }

    return {
      'total_due': due,
      'total_collected': collected,
      'outstanding': outstanding,
    };
  }
}
