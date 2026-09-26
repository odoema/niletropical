import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/notification_inbox_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() { super.initState(); _future = NotificationInboxService.fetch(); }
  Future<void> _refresh() async {
    setState(() => _future = NotificationInboxService.fetch());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthService.user != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (!signedIn) return const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Sign in to see your order updates',
              message: 'Your order notifications will appear here.',
            );
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _ErrorState(onRetry: _refresh);
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) return const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'You are all caught up',
              message: 'New order updates will appear here.',
            );
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              itemCount: rows.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final label = rows.length.toString() + ' recent update' + (rows.length == 1 ? '' : 's');
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 14),
                    child: Row(children: [
                      const Icon(Icons.notifications_active_rounded, color: NileColors.primary),
                      const SizedBox(width: 9),
                      Text(label, style: NileTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                  );
                }
                return _NotificationCard(row: rows[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.row});
  final Map<String, dynamic> row;
  Future<void> _openOrder(BuildContext context) async {
    final orderId = row['order_id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    final order = await NotificationInboxService.orderIdentity(orderId);
    if (!context.mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not open this order right now.')),
      );
      return;
    }
    final orderNumber = order['order_number']?.toString();
    final phone = order['customer_phone']?.toString();
    if (orderNumber == null || orderNumber.isEmpty) return;
    context.push('/track/$orderNumber', extra: {'phone': phone});
  }

  @override
  Widget build(BuildContext context) {
    final event = row['event_key']?.toString() ?? '';
    final orderId = row['order_id']?.toString();
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
    final positive = NotificationInboxService.isPositive(event);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: orderId == null ? null : () => _openOrder(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: positive ? NileColors.primary.withOpacity(.10) : Colors.red.withOpacity(.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(NotificationInboxService.iconFor(event),
                  color: positive ? NileColors.primary : Colors.red.shade700),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(NotificationInboxService.titleFor(event),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 5),
              Text(NotificationInboxService.messageFor(event), style: const TextStyle(height: 1.35)),
              const SizedBox(height: 9),
              Row(children: [
                if (created != null) Text(_formatDate(created),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const Spacer(),
                if (orderId != null) const Text('VIEW ORDER',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: NileColors.primary)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
  static String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return diff.inMinutes.toString() + ' min ago';
    if (diff.inDays < 1) return diff.inHours.toString() + ' hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});
  final IconData icon; final String title; final String message;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 80),
      Icon(icon, size: 64, color: NileColors.primary),
      const SizedBox(height: 18),
      Center(child: Text(title, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
      const SizedBox(height: 8),
      Center(child: Text(message, textAlign: TextAlign.center)),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 70),
      const Icon(Icons.cloud_off_rounded, size: 56),
      const SizedBox(height: 16),
      const Center(child: Text('We could not load your notifications.',
          style: TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
      Center(child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again'))),
    ],
  );
}
