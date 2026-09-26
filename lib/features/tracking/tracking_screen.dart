import 'package:flutter/material.dart';
import '../../shared/services/order_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, this.orderNumber, this.phone});
  final String? orderNumber;
  final String? phone;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final TextEditingController _orderController;
  late final TextEditingController _phoneController;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orderController = TextEditingController(text: widget.orderNumber ?? '');
    _phoneController = TextEditingController(text: widget.phone ?? '');
    if (widget.orderNumber != null && widget.phone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _track());
    }
  }

  @override
  void dispose() {
    _orderController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    final order = _orderController.text.trim();
    final phone = _phoneController.text.trim();
    if (order.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Enter your order number and the phone number used at checkout.');
      return;
    }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final data = await OrderService.trackOrder(orderNumber: order, phone: phone);
      if (!mounted) return;
      if (data == null || data['found'] != true) {
        setState(() {
          _loading = false;
          _error = 'We could not find that order. Check the order number and phone number.';
        });
        return;
      }
      setState(() { _loading = false; _result = data; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We could not load this order right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shipment = _result?['shipment'];
    final timeline = _result?['timeline'] is List ? _result!['timeline'] as List : const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Track order')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Track your Nile Tropical order', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Enter the order number and the phone number used at checkout.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _orderController,
            decoration: const InputDecoration(
              labelText: 'Order number',
              hintText: 'NTI-2026-000123',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone used at checkout',
              hintText: '07XX XXX XXX',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _track,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Loading…' : 'Track order'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_result!['order_number']?.toString() ?? 'Order',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Status: \${_result!['status']?.toString() ?? 'unknown'}'),
                    const SizedBox(height: 4),
                    Text('Payment: \${_result!['payment_status']?.toString() ?? 'unknown'}'),
                    if (_result!['total'] is num)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Total: UGX \${(_result!['total'] as num).toStringAsFixed(0)}'),
                      ),
                  ],
                ),
              ),
            ),
            if (shipment is Map && shipment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: const Text('Delivery'),
                  subtitle: Text(shipment['status']?.toString() ?? 'Shipment created'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Timeline', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (timeline.isEmpty)
              const Text('No status updates have been recorded yet.')
            else
              ...timeline.map((entry) {
                final m = entry is Map ? Map<String, dynamic>.from(entry) : <String, dynamic>{};
                final lines = [
                  m['note']?.toString() ?? '',
                  m['created_at']?.toString() ?? '',
                ].where((s) => s.isNotEmpty).join('\n');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(m['status']?.toString() ?? 'Update'),
                  subtitle: lines.isEmpty ? null : Text(lines),
                );
              }),
          ],
        ],
      ),
    );
  }
}
