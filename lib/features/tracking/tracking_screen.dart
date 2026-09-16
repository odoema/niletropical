/// Order tracking — wires track_order RPC (fixes BUG-003)
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/order_service.dart';

class TrackingScreen extends StatefulWidget {
  final String? orderNumber;
  const TrackingScreen({super.key, this.orderNumber});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _orderController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.orderNumber != null) {
      _orderController.text = widget.orderNumber!;
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
      setState(() => _error = 'Enter order number and phone');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final data = await OrderService.trackOrder(orderNumber: order, phone: phone);
      if (data == null || data['found'] != true) {
        setState(() {
          _error = 'Order not found. Check the number and phone.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _result = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Track order'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          NileTextField(
            controller: _orderController,
            label: 'Order number',
            hint: 'NTI-2026-000123',
          ),
          const SizedBox(height: NileSpacing.sm),
          NileTextField(
            controller: _phoneController,
            label: 'Phone used at checkout',
            hint: '07XX XXX XXX',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: NileSpacing.md),
          NileButton(label: 'Track', loading: _loading, onPressed: _track, icon: Icons.search),
          if (_error != null) ...[
            const SizedBox(height: NileSpacing.md),
            Text(_error!, style: NileTypography.bodyMedium.copyWith(color: NileColors.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: NileSpacing.lg),
            NileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_result!['order_number'] as String? ?? '', style: NileTypography.titleLarge),
                  const SizedBox(height: 8),
                  NileStatusChip(status: _result!['status'] as String? ?? 'unknown'),
                  const SizedBox(height: 4),
                  Text('Payment: ${_result!['payment_status']}', style: NileTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: NileSpacing.md),
            Text('Timeline', style: NileTypography.titleMedium),
            const SizedBox(height: NileSpacing.sm),
            ..._buildTimeline(_result!['timeline'] as List? ?? []),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(List timeline) {
    return timeline.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Padding(
        padding: const EdgeInsets.only(bottom: NileSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: NileColors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m['status']}', style: NileTypography.titleSmall),
                  if (m['note'] != null) Text('${m['note']}', style: NileTypography.bodyMedium),
                  Text('${m['created_at'] ?? ''}', style: NileTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
