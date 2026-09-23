import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/pod_upload_service.dart';

class _Nile {
  static const primary = Color(0xFF233E85);
  static const success = Color(0xFF1F7A4D);
  static const surface = Color(0xFFF7F8FA);
}

final _podUploadProvider = Provider<PodUploadService>((ref) {
  return PodUploadService(Supabase.instance.client);
});

/// Courier / staff Proof of Delivery with photo capture (Gap #4)
/// Usually pushed from shipment detail — not a top-level route.
class ProofOfDeliveryScreen extends ConsumerStatefulWidget {
  const ProofOfDeliveryScreen({
    super.key,
    required this.shipmentId,
    this.orderId,
    this.isCod = false,
    this.outstandingAmount,
  });

  final String shipmentId;
  final String? orderId;
  final bool isCod;
  final double? outstandingAmount;

  @override
  ConsumerState<ProofOfDeliveryScreen> createState() =>
      _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState
    extends ConsumerState<ProofOfDeliveryScreen> {
  final _customerNameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _photoPath;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.outstandingAmount != null) {
      _amountCtrl.text = widget.outstandingAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _otpCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    setState(() => _uploading = true);
    try {
      final path = await ref
          .read(_podUploadProvider)
          .captureAndUpload(widget.shipmentId);
      if (path != null) {
        setState(() => _photoPath = path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.trim());

      await Supabase.instance.client.rpc(
        'submit_proof_of_delivery',
        params: {
          'p_shipment_id': widget.shipmentId,
          'p_otp_or_signature':
              _otpCtrl.text.trim().isEmpty ? null : _otpCtrl.text.trim(),
          'p_recipient_name': _customerNameCtrl.text.trim().isEmpty
              ? null
              : _customerNameCtrl.text.trim(),
          'p_location': _locationCtrl.text.trim().isEmpty
              ? null
              : _locationCtrl.text.trim(),
          'p_otp_or_signature': _otpCtrl.text.trim().isEmpty
              ? (_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim())
              : _otpCtrl.text.trim(),
          'p_cod_collected': widget.isCod ? amount : null,
          'p_photo_storage_path': _photoPath,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proof of delivery submitted')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Nile.surface,
      appBar: AppBar(
        backgroundColor: _Nile.primary,
        foregroundColor: Colors.white,
        title: const Text('Proof of Delivery'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _customerNameCtrl,
            decoration: _dec('Customer name (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otpCtrl,
            decoration: _dec('OTP / code (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: _dec('Location (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: _dec('Notes (optional)'),
          ),
          if (widget.isCod) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Amount collected (UGX)'),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Delivery photo',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_photoPath != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: _Nile.success),
                title: const Text('Photo attached'),
                subtitle: Text(
                  _photoPath!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _uploading ? null : _capturePhoto,
                ),
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _Nile.primary,
                side: const BorderSide(color: _Nile.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _uploading ? null : _capturePhoto,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(_uploading ? 'Uploading…' : 'Take photo'),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _Nile.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit proof of delivery'),
            ),
          ),
        ],
      ),
    );
  }
}
