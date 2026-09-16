import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/media_upload.dart';
import '../../shared/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class CourierShipmentDetailScreen extends StatefulWidget {
  const CourierShipmentDetailScreen({super.key, required this.shipmentId});
  final String shipmentId;

  @override
  State<CourierShipmentDetailScreen> createState() =>
      _CourierShipmentDetailScreenState();
}

class _CourierShipmentDetailScreenState
    extends State<CourierShipmentDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _shipment;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Supabase is not configured.';
      });
      return;
    }
    try {
      String? courierId;
      if (AuthService.user != null) {
        final c = await SupabaseService.client
            .from('couriers')
            .select('id')
            .eq('auth_user_id', AuthService.user!.id)
            .maybeSingle();
        courierId = c?['id']?.toString();
      }
      final row = await SupabaseService.client
          .from('shipments')
          .select()
          .eq('id', widget.shipmentId)
          .maybeSingle();
      if (row == null) throw StateError('Shipment not found');
      if (courierId == null) {
        throw StateError('No courier profile is linked to this account.');
      }
      if (row['courier_id']?.toString() != courierId) {
        throw StateError('This shipment is not assigned to you.');
      }
      final order = await SupabaseService.client
          .from('orders')
          .select()
          .eq('id', row['order_id'])
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _shipment = row;
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<String> _nextStatuses(String current) {
    switch (current) {
      case 'pending':
      case 'assigned':
        return ['picked_up'];
      case 'picked_up':
        return ['in_transit'];
      case 'in_transit':
        return ['arrived', 'out_for_delivery'];
      case 'arrived':
        return ['out_for_delivery'];
      default:
        return const [];
    }
  }

  Future<void> _status(String status) async {
    await SupabaseService.client.rpc('update_shipment_status', params: {
      'p_shipment_id': widget.shipmentId,
      'p_status': status,
      'p_note': 'Courier update',
    });
    await _load();
  }

  Future<void> _pod({required bool collectCod}) async {
    final name = TextEditingController();
    final notes = TextEditingController();
    final photo = TextEditingController();
    final cod = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(collectCod ? 'Collect COD + POD' : 'Proof of delivery'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Recipient name')),
              TextField(controller: photo, decoration: const InputDecoration(labelText: 'POD storage path (not OTP)')),
              TextButton.icon(
                onPressed: () async {
                  final path = await MediaUpload.pickAndUpload(
                    bucket: StorageService.pod,
                    objectPath:
                        'pod/${widget.shipmentId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                    source: ImageSource.camera,
                  );
                  if (path != null) photo.text = path;
                },
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take photo'),
              ),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'OTP / signature / notes')),
              if (collectCod) ...[
                Text('Amount due: UGX ${_order?['total'] ?? '—'}'),
                TextField(
                  controller: cod,
                  decoration: const InputDecoration(labelText: 'Amount collected UGX'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    final url = photo.text.trim();
    if (url.isEmpty || url.startsWith('otp:')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide a Storage object path. Do not put OTP in the photo field.')),
      );
      return;
    }
    await SupabaseService.client.rpc('submit_proof_of_delivery', params: {
      'p_shipment_id': widget.shipmentId,
      'p_photo_storage_path': url,
      'p_recipient_name': name.text.trim(),
      'p_otp_or_signature': notes.text.trim(),
      'p_location': null,
      'p_cod_collected': collectCod ? double.tryParse(cod.text) : null,
    });
    if (!mounted) return;
    context.go('/courier');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: NileLoadingState());
    if (_error != null) {
      return Scaffold(
        appBar: const NileAppBar(title: 'Shipment'),
        body: NileErrorState(message: _error!, onRetry: _load),
      );
    }
    final s = _shipment!;
    final o = _order ?? {};
    return Scaffold(
      appBar: NileAppBar(title: 'Shipment'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          NileStatusChip(status: s['status']?.toString() ?? ''),
          const SizedBox(height: NileSpacing.md),
          NileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer', style: NileTypography.labelMedium),
                Text(o['customer_name']?.toString() ?? '—', style: NileTypography.titleMedium),
                const SizedBox(height: 8),
                Text('Phone', style: NileTypography.labelMedium),
                Text(o['customer_phone']?.toString() ?? '—', style: NileTypography.bodyLarge),
                const SizedBox(height: 8),
                Text('Address', style: NileTypography.labelMedium),
                Text(o['delivery_address']?.toString() ?? '—', style: NileTypography.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: NileSpacing.lg),
          ..._nextStatuses(s['status']?.toString() ?? '').map(
            (st) => Padding(
              padding: const EdgeInsets.only(bottom: NileSpacing.sm),
              child: NileOutlinedButton(
                label: st.replaceAll('_', ' '),
                onPressed: () => _status(st),
              ),
            ),
          ),
          const SizedBox(height: NileSpacing.md),
          NileButton(
            label: 'Capture proof of delivery',
            icon: Icons.camera_alt_outlined,
            onPressed: () => _pod(collectCod: false),
          ),
          const SizedBox(height: NileSpacing.sm),
          NileOutlinedButton(
            label: 'Collect COD',
            icon: Icons.payments_outlined,
            onPressed: () => _pod(collectCod: true),
          ),
        ],
      ),
    );
  }
}
