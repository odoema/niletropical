import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String? _error;
  int ordersToday = 0;
  int paidOrders = 0;
  int pendingPay = 0;
  int delivered = 0;
  double revenuePaid = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Connect Supabase to load live reports. No placeholder figures are shown.';
      });
      return;
    }
    try {
      final start = DateTime.now().toUtc();
      final dayStart = DateTime.utc(start.year, start.month, start.day).toIso8601String();
      final rows = await SupabaseService.client
          .from('orders')
          .select('id, total, payment_status, status, created_at');
      final list = List<Map<String, dynamic>>.from(rows);
      var today = 0, paid = 0, pending = 0, deliv = 0;
      var rev = 0.0;
      for (final o in list) {
        final created = o['created_at']?.toString() ?? '';
        if (created.compareTo(dayStart) >= 0) today++;
        final pay = o['payment_status']?.toString();
        if (pay == 'paid' || pay == 'successful') {
          paid++;
          rev += (o['total'] as num?)?.toDouble() ?? 0;
        }
        if (pay == 'pending' || pay == 'unpaid') pending++;
        if (o['status'] == 'delivered') deliv++;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        ordersToday = today;
        paidOrders = paid;
        pendingPay = pending;
        delivered = deliv;
        revenuePaid = rev;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () {
          setState(() => _loading = true);
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Live orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip('Orders today', '$ordersToday'),
                        _chip('Paid', '$paidOrders'),
                        _chip('Pending pay', '$pendingPay'),
                        _chip('Delivered', '$delivered'),
                        _chip('Paid revenue', '${AppConstants.currencySymbol}${revenuePaid.toStringAsFixed(0)}'),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NileColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NileColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: NileColors.primary)),
          Text(label, style: const TextStyle(color: NileColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
