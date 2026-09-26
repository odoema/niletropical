/// Nile Tropical - Delivery Operations Console
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/delivery.dart';
import '../../shared/services/delivery_service.dart';
import '../../shared/services/location_search_service.dart';
import 'nile_delivery_map.dart';

final zonesProvider = FutureProvider<List<DeliveryZone>>((ref) => DeliveryService.getZones());
final partnersProvider = FutureProvider<List<DeliveryPartner>>((ref) => DeliveryService.getPartners());
final couriersProvider = FutureProvider<List<Courier>>((ref) => DeliveryService.getCouriers());

class DeliveryDashboardScreen extends ConsumerStatefulWidget {
  const DeliveryDashboardScreen({super.key});
  @override
  ConsumerState<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends ConsumerState<DeliveryDashboardScreen> {
  final _originCtrl = TextEditingController(text: 'Kampala, Uganda');
  final _destinationCtrl = TextEditingController();
  Timer? _destinationDebounce;
  List<GeoPlace> _originResults = const [];
  List<GeoPlace> _destinationResults = const [];
  GeoPlace? _origin;
  GeoPlace? _destination;
  RouteEstimate? _route;
  bool _searchingOrigin = false;
  bool _searchingDestination = false;
  bool _calculating = false;
  String? _locationError;

  String? _quoteZoneId;
  Map<String, dynamic>? _serverQuote;

  @override
  void dispose() {
    _destinationDebounce?.cancel();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchOrigin() async {
    if (_originCtrl.text.trim().length < 3) return;
    setState(() => _searchingOrigin = true);
    try {
      final results = await LocationSearchService.search(_originCtrl.text);
      if (mounted) setState(() => _originResults = results);
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _searchingOrigin = false);
    }
  }

  void _scheduleDestinationSearch(String value) {
    _destinationDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _destinationResults = const []);
      return;
    }
    _destinationDebounce = Timer(const Duration(milliseconds: 650), () async {
      setState(() => _searchingDestination = true);
      try {
        final results = await LocationSearchService.search(value);
        if (mounted) setState(() => _destinationResults = results);
      } catch (e) {
        if (mounted) setState(() => _locationError = e.toString());
      } finally {
        if (mounted) setState(() => _searchingDestination = false);
      }
    });
  }

  void _ensurePricingZone(List<DeliveryZone> zones) {
    if (zones.isEmpty || _quoteZoneId != null) return;

    // Kampala is the safest operational default for a Kampala-origin console,
    // while still allowing the operator to change the zone before quoting.
    final preferred = zones.firstWhere(
      (z) => z.name.toLowerCase().contains('kampala'),
      orElse: () => zones.first,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _quoteZoneId != null) return;
      setState(() => _quoteZoneId = preferred.id);
    });
  }

  void _autoSelectZoneForPlace(GeoPlace place) {
    final zones = ref.read(zonesProvider).valueOrNull ?? const <DeliveryZone>[];
    if (zones.isEmpty) return;

    final placeText = place.name.toLowerCase();
    DeliveryZone? match;

    // Prefer an explicit zone-name match, e.g. "Bukoto, Kampala" -> Kampala.
    for (final zone in zones) {
      final zoneName = zone.name.trim().toLowerCase();
      if (zoneName.isNotEmpty && placeText.contains(zoneName)) {
        match = zone;
        break;
      }
    }

    if (match == null && placeText.contains('kampala')) {
      for (final zone in zones) {
        if (zone.name.toLowerCase().contains('kampala')) {
          match = zone;
          break;
        }
      }
    }

    if (match != null && mounted) {
      setState(() {
        _quoteZoneId = match!.id;
        _serverQuote = null;
      });
    }
  }

  Future<void> _calculateQuote() async {
    setState(() {
      _calculating = true;
      _locationError = null;
    });
    try {
      var origin = _origin;
      if (origin == null) {
        final results = await LocationSearchService.search(_originCtrl.text);
        if (results.isEmpty) throw Exception('Dispatch origin could not be located.');
        origin = results.first;
      }
      var destination = _destination;
      if (destination == null) {
        final results = await LocationSearchService.search(_destinationCtrl.text);
        if (results.isEmpty) throw Exception('Customer destination could not be located.');
        destination = results.first;
      }
      final route = await LocationSearchService.route(
        origin: origin,
        destination: destination,
      );
      if (_quoteZoneId == null) {
        throw Exception('Select a pricing zone for the quote.');
      }
      final serverQuote = await DeliveryService.quoteDelivery(
        deliveryZoneId: _quoteZoneId!,
        distanceKm: route.distanceKm,
      );
      if (!mounted) return;
      setState(() {
        _origin = origin;
        _destination = destination;
        _route = route;
        _serverQuote = serverQuote;
      });
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }


  Future<void> _openGoogleMaps() async {
    if (_origin == null || _destination == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_origin!.latitude},${_origin!.longitude}'
      '&destination=${_destination!.latitude},${_destination!.longitude}'
      '&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _addZone(BuildContext context) async {
    final name = TextEditingController();
    final fee = TextEditingController();
    final days = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add delivery zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Zone name')),
            TextField(controller: fee, decoration: const InputDecoration(labelText: 'Base fee UGX'), keyboardType: TextInputType.number),
            TextField(controller: days, decoration: const InputDecoration(labelText: 'Estimated days'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await DeliveryService.createZone(
        name: name.text.trim(),
        fee: double.tryParse(fee.text) ?? 0,
        estimatedDays: int.tryParse(days.text),
      );
      ref.invalidate(zonesProvider);
    }
  }

  Future<void> _addCourier(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final vehicle = TextEditingController();
    final area = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add courier / rider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: vehicle, decoration: const InputDecoration(labelText: 'Vehicle type (Boda, car, van…)')),
            TextField(controller: area, decoration: const InputDecoration(labelText: 'Operating area')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await DeliveryService.createCourier(
        fullName: name.text.trim(),
        phone: phone.text.trim(),
        vehicleType: vehicle.text.trim().isEmpty ? null : vehicle.text.trim(),
        operatingArea: area.text.trim().isEmpty ? null : area.text.trim(),
      );
      ref.invalidate(couriersProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesProvider);
    final partnersAsync = ref.watch(partnersProvider);
    final couriersAsync = ref.watch(couriersProvider);

    return Scaffold(
      backgroundColor: NileColors.surface,
      appBar: AppBar(
        backgroundColor: NileColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(zonesProvider);
              ref.invalidate(partnersProvider);
              ref.invalidate(couriersProvider);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _quoteCard(wide),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _addZone(context), icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add Zone'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _addCourier(context), icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Add Courier'))),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('Delivery Zones', 'Service coverage zones; the route quote is distance-based'),
              zonesAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (e, _) => Text('Could not load zones: $e'),
                data: (zones) => _zonesGrid(zones, wide),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Transport Partners', 'Bus, taxi, courier and other last-mile partners'),
              partnersAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (e, _) => Text('Could not load partners: $e'),
                data: (partners) => _partnersGrid(partners, wide),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Couriers & Riders', 'Operational riders available for dispatch'),
              couriersAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (e, _) => Text('Could not load couriers: $e'),
                data: (couriers) => _couriersGrid(couriers, wide),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _quoteCard(bool wide) {
    final result = _route;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [NileColors.primary, NileColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.route_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Smart Delivery Quote', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Search a destination, calculate the road route and produce a distance-based delivery quote.', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 12)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 700;
                final origin = _locationField(
                  controller: _originCtrl,
                  label: 'Dispatch origin',
                  hint: 'Warehouse / starting point',
                  icon: Icons.storefront_outlined,
                  results: _originResults,
                  loading: _searchingOrigin,
                  onChanged: (_) {
                    _origin = null;
                    _route = null;
                    _serverQuote = null;
                  },
                  onSearch: _searchOrigin,
                  onPick: (p) => setState(() {
                    _origin = p;
                    _originCtrl.text = p.name;
                    _originResults = const [];
                    _route = null;
                    _serverQuote = null;
                  }),
                );
                final zone = _zoneSelector();
                final destination = _locationField(
                  controller: _destinationCtrl,
                  label: 'Customer destination',
                  hint: 'Start typing an address or landmark',
                  icon: Icons.location_on_outlined,
                  results: _destinationResults,
                  loading: _searchingDestination,
                  onChanged: (v) {
                    _destination = null;
                    _scheduleDestinationSearch(v);
                  },
                  onSearch: () => _scheduleDestinationSearch(_destinationCtrl.text),
                  onPick: (p) {
                    setState(() {
                      _destination = p;
                      _destinationCtrl.text = p.name;
                      _destinationResults = const [];
                      _route = null;
                      _serverQuote = null;
                    });
                    _autoSelectZoneForPlace(p);
                  },
                );
                return compact
                    ? Column(children: [zone, const SizedBox(height: 10), origin, const SizedBox(height: 10), destination, const SizedBox(height: 12), _quoteButton()])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Column(children: [zone, const SizedBox(height: 10), origin])),
                          const Padding(padding: EdgeInsets.only(top: 18, left: 8, right: 8), child: Icon(Icons.arrow_forward_rounded, color: Colors.white70)),
                          Expanded(child: destination),
                          const SizedBox(width: 10),
                          Padding(padding: const EdgeInsets.only(top: 18), child: _quoteButton()),
                        ],
                      );
              },
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 10),
              Text(_locationError!, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
            if (_origin != null && _destination != null) ...[
              const SizedBox(height: 16),
              NileDeliveryMap(
                origin: _origin!,
                destination: _destination!,
                route: result,
                height: wide ? 380 : 300,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _metric('ROAD DISTANCE', '${result.distanceKm.toStringAsFixed(1)} km'),
                    _metric('ETA', '${result.durationMinutes.ceil()} min'),
                    _metric('EST. DELIVERY', 'UGX ${((_serverQuote?['delivery_fee'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
                    OutlinedButton.icon(
                      onPressed: _openGoogleMaps,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Open in Maps'),
                    ),

                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _zoneSelector() {
    final zones = ref.watch(zonesProvider).valueOrNull ?? const <DeliveryZone>[];
    _ensurePricingZone(zones);

    return DropdownButtonFormField<String>(
      value: _quoteZoneId,
      dropdownColor: NileColors.primaryDark,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: 'Service zone',
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.price_check_rounded, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .10),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white30)),
      ),
      items: zones.map((z) => DropdownMenuItem<String>(
        value: z.id,
        child: Text(z.name),
      )).toList(),
      onChanged: (value) {
        setState(() {
          _quoteZoneId = value;
          _serverQuote = null;
          _route = null;
        });
      },
    );
  }

  Widget _quoteButton() {
    return FilledButton.icon(
      onPressed: _calculating || _quoteZoneId == null || _destinationCtrl.text.trim().length < 3 ? null : _calculateQuote,
      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: NileColors.primary, minimumSize: const Size(150, 46)),
      icon: _calculating ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate_outlined, size: 18),
      label: Text(_calculating ? 'Calculating…' : 'Get quote'),
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<GeoPlace> results,
    required bool loading,
    required ValueChanged<String> onChanged,
    required VoidCallback onSearch,
    required ValueChanged<GeoPlace> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: (_) => onSearch(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white60),
            prefixIcon: Icon(icon, color: Colors.white70),
            suffixIcon: loading
                ? const Padding(padding: EdgeInsets.all(13), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded, color: Colors.white)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: .10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white30)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white)),
          ),
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: results.map((p) => ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined, color: NileColors.primary),
                title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => onPick(p),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .7)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _zonesGrid(List<DeliveryZone> zones, bool wide) {
    if (zones.isEmpty) return _empty('No delivery zones configured.');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: zones.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 3 : 1, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 82),
      itemBuilder: (_, i) {
        final z = zones[i];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: NileColors.primary.withValues(alpha: .10), child: const Icon(Icons.location_on_outlined, color: NileColors.primary)),
            title: Text(z.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(z.estimatedDays != null ? '${z.estimatedDays} day(s) estimated' : 'Estimated time not set'),
            trailing: Text('UGX ${z.deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: NileColors.primary)),
          ),
        );
      },
    );
  }

  Widget _partnersGrid(List<DeliveryPartner> partners, bool wide) {
    if (partners.isEmpty) return _empty('No transport partners configured.');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: partners.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 3 : 1, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 86),
      itemBuilder: (_, i) {
        final p = partners[i];
        final icon = p.type == DeliveryPartnerType.boda ? Icons.two_wheeler : Icons.local_shipping_outlined;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: NileColors.secondary.withValues(alpha: .12), child: Icon(icon, color: NileColors.secondary)),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${p.type.label}${p.terminal != null ? ' • ${p.terminal}' : ''}${p.phone != null ? ' • ${p.phone}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
      },
    );
  }

  Widget _couriersGrid(List<Courier> couriers, bool wide) {
    if (couriers.isEmpty) return _empty('No active couriers or riders configured.');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: couriers.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 3 : 1, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 86),
      itemBuilder: (_, i) {
        final c = couriers[i];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: NileColors.accent.withValues(alpha: .12), child: Text(c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w800, color: NileColors.accent))),
            title: Text(c.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${c.vehicleType ?? 'Vehicle not set'} • ${c.operatingArea ?? 'Area not set'} • ${c.phone}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: c.commissionRate == null ? null : Text('${c.commissionRate!.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        );
      },
    );
  }

  Widget _empty(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [const Icon(Icons.info_outline, color: NileColors.primary), const SizedBox(width: 10), Expanded(child: Text(text))]),
    );
  }
}
