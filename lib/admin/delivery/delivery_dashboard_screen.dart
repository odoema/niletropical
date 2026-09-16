/// Nile Tropical - Delivery Dashboard (Admin)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/delivery.dart';
import '../../shared/services/delivery_service.dart';

final zonesProvider = FutureProvider<List<DeliveryZone>>((ref) {
  return DeliveryService.getZones();
});

final partnersProvider = FutureProvider<List<DeliveryPartner>>((ref) {
  return DeliveryService.getPartners();
});

final couriersProvider = FutureProvider<List<Courier>>((ref) {
  return DeliveryService.getCouriers();
});

class DeliveryDashboardScreen extends ConsumerWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(zonesProvider);
    final partnersAsync = ref.watch(partnersProvider);
    final couriersAsync = ref.watch(couriersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(zonesProvider);
              ref.invalidate(partnersProvider);
              ref.invalidate(couriersProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final name = TextEditingController();
                    final fee = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Add zone'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                            TextField(controller: fee, decoration: const InputDecoration(labelText: 'Fee UGX'), keyboardType: TextInputType.number),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await DeliveryService.createZone(
                        name: name.text.trim(),
                        fee: double.tryParse(fee.text) ?? 0,
                      );
                      ref.invalidate(zonesProvider);
                    }
                  },
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add Zone'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final name = TextEditingController();
                    final phone = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Add courier'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await DeliveryService.createCourier(
                        fullName: name.text.trim(),
                        phone: phone.text.trim(),
                      );
                      ref.invalidate(couriersProvider);
                    }
                  },
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add Courier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Delivery Zones
          const Text(
            'Delivery Zones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          zonesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (zones) => Column(
              children: zones
                  .map((z) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: NileColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.location_on,
                                color: NileColors.primary),
                          ),
                          title: Text(z.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            z.estimatedDays != null
                                ? '${z.estimatedDays} day(s) estimated'
                                : 'Fee only',
                          ),
                          trailing: Text(
                            'UGX ${z.deliveryFee.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: NileColors.primary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),

          // Transport Partners
          const Text(
            'Transport Partners',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          partnersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (partners) => Column(
              children: partners
                  .map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: NileColors.secondary.withOpacity(0.15),
                            child: Icon(
                              p.type == DeliveryPartnerType.boda
                                  ? Icons.two_wheeler
                                  : Icons.directions_bus,
                              color: NileColors.secondary,
                            ),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${p.type.label}'
                            '${p.terminal != null ? ' • ${p.terminal}' : ''}'
                            '${p.phone != null ? '\n${p.phone}' : ''}',
                          ),
                          isThreeLine: p.phone != null,
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),

          // Couriers / Riders
          const Text(
            'Couriers / Riders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          couriersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (couriers) => Column(
              children: couriers
                  .map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: NileColors.accent.withOpacity(0.15),
                            child: Text(
                              c.fullName.isNotEmpty ? c.fullName[0] : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: NileColors.accent,
                              ),
                            ),
                          ),
                          title: Text(c.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${c.operatingArea ?? '—'} • ${c.vehicleType ?? '—'}'
                            '\n${c.phone}',
                          ),
                          isThreeLine: true,
                          trailing: c.commissionRate != null
                              ? Text('${c.commissionRate!.toStringAsFixed(0)}%')
                              : null,
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
