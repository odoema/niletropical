import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  int _rangeDays = 7;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _business;

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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await SupabaseService.client.functions.invoke(
        'analytics-dashboard',
        body: {'range': _rangeDays.toString()},
      );

      if (response.data is! Map) {
        throw StateError('Analytics returned an invalid response.');
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['ok'] != true) {
        throw StateError(data['error']?.toString() ?? 'Analytics request failed.');
      }

      final business = await _loadBusinessSnapshot();

      if (!mounted) return;
      setState(() {
        _data = data;
        _business = business;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<Map<String, dynamic>> _loadBusinessSnapshot() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _rangeDays - 1));

    final rows = await SupabaseService.client
        .from('orders')
        .select('total,payment_status,status,created_at')
        .gte('created_at', start.toUtc().toIso8601String());

    var orders = 0;
    var paid = 0;
    var pending = 0;
    var delivered = 0;
    var revenue = 0.0;

    for (final row in List<Map<String, dynamic>>.from(rows)) {
      orders++;
      final payment = row['payment_status']?.toString();
      if (payment == 'paid' || payment == 'successful') {
        paid++;
        revenue += (row['total'] as num?)?.toDouble() ?? 0;
      }
      if (payment == 'pending' || payment == 'unpaid') pending++;
      if (row['status']?.toString() == 'delivered') delivered++;
    }

    return {
      'orders': orders,
      'paid': paid,
      'pending': pending,
      'delivered': delivered,
      'revenue': revenue,
    };
  }

  int _number(dynamic value) =>
      (value as num?)?.round() ?? int.tryParse(value?.toString() ?? '') ?? 0;

  double _double(dynamic value) =>
      (value as num?)?.toDouble() ?? double.tryParse(value?.toString() ?? '') ?? 0;

  List<Map<String, dynamic>> _rows(String key) {
    final value = _data?[key];
    if (value is! List) return const [];
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _realtimeCountries() {
    final value = (_data?['realtime'] as Map?)?['countries'];
    if (value is! List) return const [];
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _openGoogleAnalytics() async {
    await launchUrl(
      Uri.parse('https://analytics.google.com/'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = Map<String, dynamic>.from(_data?['overview'] ?? {});
    final realtime = Map<String, dynamic>.from(_data?['realtime'] ?? {});
    final trend = _rows('trend');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rangeDays,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
                DropdownMenuItem(value: 90, child: Text('90 days')),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _rangeDays = value);
                      _load();
                    },
            ),
          ),
          IconButton(
            tooltip: 'Refresh analytics',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(NileSpacing.md),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nile Tropical Analytics',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: NileTypography.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _openGoogleAnalytics,
                        icon: const Icon(Icons.open_in_new, size: 17),
                        label: const Text('Google Analytics'),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Nile Tropical Analytics',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: NileTypography.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _openGoogleAnalytics,
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: const Text('Google Analytics'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Website intelligence and commerce performance for the last ' +
                  _rangeDays.toString() +
                  ' days.',
              style: NileTypography.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              NileCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: NileColors.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('Website overview', style: NileTypography.titleLarge),
            const SizedBox(height: 10),
            _grid([
              _metric('Active users', _number(overview['activeUsers']), Icons.people_outline),
              _metric('Sessions', _number(overview['sessions']), Icons.login_outlined),
              _metric('Page views', _number(overview['screenPageViews']), Icons.visibility_outlined),
              _metric('Events', _number(overview['eventCount']), Icons.bolt_outlined),
            ]),
            const SizedBox(height: 18),
            Text('Live now', style: NileTypography.titleLarge),
            const SizedBox(height: 10),
            NileCard(
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 12, color: NileColors.success),
                  const SizedBox(width: 8),
                  Text(
                    _number(realtime['activeUsers']).toString() + ' active user(s)',
                    style: NileTypography.titleMedium,
                  ),
                  const Spacer(),
                  ..._realtimeCountries().take(4).map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        row['country'].toString() +
                            ': ' +
                            _number(row['activeUsers']).toString(),
                        style: NileTypography.caption,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Traffic trend', style: NileTypography.titleLarge),
            const SizedBox(height: 10),
            _trendCard(trend),
            const SizedBox(height: 18),
            _twoColumns(
              _dataCard(
                'Traffic sources',
                Icons.alt_route_outlined,
                _rows('sources'),
                'source',
                'sessions',
              ),
              _dataCard(
                'Top countries',
                Icons.public_outlined,
                _rows('countries'),
                'country',
                'activeUsers',
              ),
            ),
            const SizedBox(height: 18),
            _twoColumns(
              _dataCard(
                'Top pages',
                Icons.web_outlined,
                _rows('pages'),
                'pageTitle',
                'screenPageViews',
              ),
              _dataCard(
                'Top events',
                Icons.bolt_outlined,
                _rows('events'),
                'eventName',
                'eventCount',
              ),
            ),
            const SizedBox(height: 18),
            Text('Nile Tropical commerce', style: NileTypography.titleLarge),
            const SizedBox(height: 10),
            _grid([
              _metric('Orders', _number(_business?['orders']), Icons.receipt_long_outlined),
              _metric('Paid orders', _number(_business?['paid']), Icons.verified_outlined),
              _metric('Pending payment', _number(_business?['pending']), Icons.hourglass_top_outlined),
              _metric('Delivered', _number(_business?['delivered']), Icons.local_shipping_outlined),
              _metric(
                'Paid revenue',
                'UGX ' + NumberFormat('#,##0').format(_double(_business?['revenue'])),
                Icons.payments_outlined,
              ),
            ]),
            const SizedBox(height: 28),
            Center(
              child: Text(
                _data?['generatedAt'] == null
                    ? 'Analytics not connected'
                    : 'Last refreshed ' + _formatTime(_data!['generatedAt'].toString()),
                style: NileTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep KPI cards compact on desktop so four fit comfortably in one row.
        // On smaller screens we step down gracefully without affecting the customer UI.
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 4
              ? 3.55
              : columns == 2
                  ? 3.0
                  : 3.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }

  Widget _metric(String label, dynamic value, IconData icon) {
    return NileCard(
      child: Row(
        children: [
          Icon(icon, color: NileColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NileTypography.headlineMedium,
                ),
                const SizedBox(height: 2),
                Text(label, style: NileTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _twoColumns(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _dataCard(
    String title,
    IconData icon,
    List<Map<String, dynamic>> rows,
    String labelKey,
    String valueKey,
  ) {
    return NileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: NileColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: NileTypography.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('No data yet.')
          else
            ...rows.take(8).map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row[labelKey]?.toString() ?? '(not set)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      NumberFormat('#,##0').format(_number(row[valueKey])),
                      style: NileTypography.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _trendCard(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return const NileCard(child: Text('No trend data yet.'));
    }

    final maxValue = trend.fold<double>(
      1,
      (max, row) => [
        max,
        _double(row['activeUsers']),
        _double(row['sessions']),
      ].reduce((a, b) => a > b ? a : b),
    );

    return NileCard(
      child: Column(
        children: trend.take(14).map((row) {
          final active = _double(row['activeUsers']);
          final sessions = _double(row['sessions']);
          final date = row['date']?.toString() ?? '';
          final label = date.length >= 8
              ? date.substring(4, 6) + '/' + date.substring(6, 8)
              : date;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 42, child: Text(label, style: NileTypography.caption)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: maxValue == 0 ? 0 : active / maxValue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                    backgroundColor: NileColors.border,
                    color: NileColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 70,
                  child: Text(
                    active.round().toString() + ' users',
                    textAlign: TextAlign.right,
                    style: NileTypography.caption,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 70,
                  child: Text(
                    sessions.round().toString() + ' sess.',
                    textAlign: TextAlign.right,
                    style: NileTypography.caption,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
