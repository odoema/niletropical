import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/push_notification_service.dart';
import '../services/supabase_service.dart';

class PushNotificationPrompt extends StatefulWidget {
  final Widget child;

  const PushNotificationPrompt({super.key, required this.child});

  @override
  State<PushNotificationPrompt> createState() => _PushNotificationPromptState();
}

class _PushNotificationPromptState extends State<PushNotificationPrompt> {
  bool _visible = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), _refresh);
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) _refresh();
    });
  }

  void _refresh() {
    if (!mounted || !PushNotificationService.isSupported) return;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _visible = PushNotificationService.permission == 'default';
    });
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final ok = await PushNotificationService.enable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _visible = !ok;
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order notifications are now enabled on this device.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            right: 18,
            bottom: 18,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 330),
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Get free order updates on this device.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _busy ? null : _enable,
                      child: Text(_busy ? '...' : 'Enable'),
                    ),
                    IconButton(
                      tooltip: 'Not now',
                      onPressed: () => setState(() => _visible = false),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
