/// Nile Tropical - Proof of Delivery Screen
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/media_upload.dart';
import '../../shared/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class ProofOfDeliveryScreen extends StatefulWidget {
  final String orderId;

  const ProofOfDeliveryScreen({super.key, required this.orderId});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final _otpController = TextEditingController();
  final _notesController = TextEditingController();
  final _codController = TextEditingController();
  bool _isCod = false;
  bool _saving = false;
  String? _photoPath;

  @override
  void dispose() {
    _otpController.dispose();
    _notesController.dispose();
    _codController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      if (!Env.isConfigured) {
        throw StateError('Supabase is not configured. POD was not saved.');
      }
      final shipment = await SupabaseService.client
          .from('shipments')
          .select('id')
          .eq('order_id', widget.orderId)
          .maybeSingle();
      if (shipment == null) {
        throw StateError('No shipment for this order.');
      }
      // Parameter mapping matches the rewritten 020_shipment_rpcs.sql:
      //   p_photo_storage_path   — real photo path in Supabase Storage
      //   p_otp_or_signature     — the customer-supplied OTP or signature
      // Previously the OTP was stuffed into the photo URL slot, which
      // meant no POD row could ever be searched by real photo path.
      //
      // Real photo capture + Storage upload is the next piece of work
      // (image_picker → Storage → path). Until then p_photo_storage_path
      // stays null and the OTP is captured in the right column.
      await SupabaseService.client.rpc('submit_proof_of_delivery', params: {
        'p_shipment_id': shipment['id'],
        'p_photo_storage_path': _photoPath,
        'p_recipient_name': null,
        'p_otp_or_signature': _otpController.text.trim(),
        'p_location': null,
        'p_cod_collected':
            _isCod ? double.tryParse(_codController.text) : null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof of Delivery recorded.'),
          backgroundColor: NileColors.success,
        ),
      );
      context.go('/admin/orders');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('POD failed: $e'),
          backgroundColor: NileColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Confirm delivery details',
            style: TextStyle(fontSize: 16, color: NileColors.textSecondary),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _otpController,
            decoration: const InputDecoration(
              labelText: 'OTP / Verification Code',
              hintText: 'Enter code from customer',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Cash on Delivery collected'),
            value: _isCod,
            onChanged: (v) => setState(() => _isCod = v),
            activeColor: NileColors.primary,
          ),

          if (_isCod) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _codController,
              decoration: const InputDecoration(
                labelText: 'Amount Collected (UGX)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),

          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Any delivery remarks',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              final path = await MediaUpload.pickAndUpload(
                bucket: StorageService.pod,
                objectPath:
                    'pod/${widget.orderId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                source: ImageSource.camera,
              );
              if (path != null && mounted) setState(() => _photoPath = path);
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_photoPath == null ? 'Take POD photo' : 'Photo saved: $_photoPath'),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm Delivery'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
