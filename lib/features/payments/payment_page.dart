import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/constants/payment_methods.dart';
import '../../shared/services/payment_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.orderId,
    this.orderNumber,
    this.method,
    this.phone,
    this.total,
  });

  final String orderId;
  final String? orderNumber;
  final String? method;
  final String? phone;
  final double? total;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late String _method;
  bool _loading = false;
  String _phase = 'ready'; // ready | pending | checking | failed
  String? _reference;
  String? _instructions;
  String? _redirectUrl; // hosted card page (Pesapal)
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _method = PaymentMethods.normalize(widget.method);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await PaymentService.initiate(
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
        method: _method,
        phone: widget.phone,
      );
      if (!mounted) return;
      if (res['error'] != null) {
        setState(() {
          _loading = false;
          _phase = 'failed';
          _error = res['error'].toString();
        });
        return;
      }
      setState(() {
        _loading = false;
        _phase = 'pending';
        _reference = res['reference']?.toString();
        _instructions = res['instructions']?.toString();
        _redirectUrl = res['redirect_url']?.toString();
      });
      // Best effort: browsers may block a pop-up opened after a network call,
      // so the pending screen also shows an explicit "Open payment page" button.
      if (_redirectUrl != null && _redirectUrl!.isNotEmpty) {
        await _openPaymentPage();
      }
      _startPoll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _phase = 'failed';
        _error = e.toString();
      });
    }
  }

  Future<void> _openPaymentPage() async {
    final url = _redirectUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    // Only ever open the https payment page returned by our own server.
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  Future<void> _check() async {
    final ref = _reference;
    if (ref == null) return;
    setState(() => _phase = 'checking');
    try {
      final res = await PaymentService.status(
        ref,
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
      );
      if (!mounted) return;
      final status = (res['status'] ?? '').toString();
      if (status == 'successful' || status == 'paid' || status == 'success') {
        _poll?.cancel();
        context.go('/confirmation', extra: {
          'orderNumber': res['order_number']?.toString() ??
              widget.orderNumber ??
              widget.orderId,
          'total': (res['total'] as num?)?.toDouble() ??
              widget.total ??
              0,
          'paymentMethod': _method,
          'phone': widget.phone,
        });
        return;
      }
      if (status == 'failed' || status == 'cancelled') {
        _poll?.cancel();
        setState(() {
          _phase = 'failed';
          _error = 'Payment $status';
        });
        return;
      }
      setState(() => _phase = 'pending');
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = 'pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Pay for order'),
      body: Padding(
        padding: const EdgeInsets.all(NileSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.orderNumber != null)
              Text(widget.orderNumber!, style: NileTypography.titleLarge),
            if (widget.total != null) ...[
              const SizedBox(height: 4),
              NilePrice(amount: widget.total!, style: NileTypography.headlineSmall),
            ],
            const SizedBox(height: NileSpacing.md),
            if (_phase == 'ready') ...[
              Text('Payment method', style: NileTypography.titleMedium),
              const SizedBox(height: NileSpacing.sm),
              NileCard(
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: NileColors.primary),
                    const SizedBox(width: NileSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PaymentMethods.labels[_method] ?? _method,
                            style: NileTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Payment method is fixed to the method selected at checkout.',
                            style: NileTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              NileButton(
                label: 'Pay now',
                loading: _loading,
                onPressed: _pay,
                icon: Icons.lock_outline,
              ),
            ] else if (_phase == 'pending' || _phase == 'checking') ...[
              Text(
                _phase == 'checking'
                    ? 'Checking payment'
                    : (_redirectUrl != null
                        ? 'Complete your payment'
                        : 'Approve on your phone'),
                style: NileTypography.headlineSmall,
              ),
              const SizedBox(height: NileSpacing.sm),
              Text(
                _instructions ??
                    'A prompt was sent. Enter your PIN. Do not close this screen.',
                style: NileTypography.bodyMedium,
              ),
              if (_reference != null) ...[
                const SizedBox(height: NileSpacing.sm),
                Text('Ref $_reference', style: NileTypography.bodySmall),
              ],
              const Spacer(),
              if (_redirectUrl != null) ...[
                NileButton(
                  label: 'Open payment page',
                  icon: Icons.lock_outline,
                  onPressed: _openPaymentPage,
                ),
                const SizedBox(height: NileSpacing.sm),
              ],
              NileButton(
                label: 'Check payment status',
                loading: _phase == 'checking',
                onPressed: _check,
              ),
              const SizedBox(height: NileSpacing.sm),
              NileOutlinedButton(
                label: 'Resend prompt',
                onPressed: _loading ? null : _pay,
              ),
            ] else ...[
              Text('Payment failed', style: NileTypography.headlineSmall),
              const SizedBox(height: NileSpacing.sm),
              Text(_error ?? 'Try again', style: NileTypography.bodyMedium),
              const Spacer(),
              NileButton(label: 'Retry payment', onPressed: _pay),
            ],
          ],
        ),
      ),
    );
  }
}
