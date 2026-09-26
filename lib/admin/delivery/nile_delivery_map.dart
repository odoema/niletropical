import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/location_search_service.dart';

class NileDeliveryMap extends StatelessWidget {
  const NileDeliveryMap({
    super.key,
    required this.origin,
    required this.destination,
    this.route,
    this.height = 360,
  });

  final GeoPlace origin;
  final GeoPlace destination;
  final RouteEstimate? route;
  final double height;

  @override
  Widget build(BuildContext context) {
    final originPoint = LatLng(origin.latitude, origin.longitude);
    final destinationPoint = LatLng(destination.latitude, destination.longitude);
    final routePoints = route?.geometry
            .map((p) => LatLng(p[0], p[1]))
            .toList(growable: false) ??
        const <LatLng>[];

    final points = <LatLng>[
      originPoint,
      destinationPoint,
      ...routePoints,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _center(points),
                initialZoom: _zoom(points),
                initialCameraFit: points.length >= 2
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(42),
                        maxZoom: 16,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.niletropical.uganda',
                ),
                if (routePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 5,
                        color: NileColors.accent,
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: originPoint,
                      width: 44,
                      height: 44,
                      child: _pin(Icons.storefront_rounded, NileColors.primary),
                    ),
                    Marker(
                      point: destinationPoint,
                      width: 44,
                      height: 44,
                      child: _pin(Icons.location_on_rounded, NileColors.accent),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _legend(),
            ),
            if (route == null)
              Positioned(
                right: 12,
                bottom: 12,
                child: _statusChip(
                  Icons.touch_app_outlined,
                  'Interactive map • drag / zoom',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pin(IconData icon, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Colors.black26,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 21),
    );
  }

  Widget _legend() {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, size: 16, color: NileColors.primary),
            const SizedBox(width: 5),
            const Text('Nile Tropical', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Icon(Icons.location_on_rounded, size: 16, color: NileColors.accent),
            const SizedBox(width: 5),
            const Text('Customer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String text) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: NileColors.primary),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  LatLng _center(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  double _zoom(List<LatLng> points) {
    if (points.length < 2) return 12;
    final latSpan = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b) -
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final lngSpan = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b) -
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final span = latSpan > lngSpan ? latSpan : lngSpan;
    if (span < 0.01) return 14;
    if (span < 0.03) return 12.5;
    if (span < 0.08) return 11.5;
    if (span < 0.2) return 10.5;
    return 9.5;
  }
}
