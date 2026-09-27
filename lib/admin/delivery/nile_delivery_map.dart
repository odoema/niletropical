import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/location_search_service.dart';

/// Interactive delivery map used by both checkout and the admin delivery console.
///
/// The customer marker can be dragged to correct an address/landmark position.
/// The parent owns the selected destination and should clear any route/quote
/// when the marker moves.
class NileDeliveryMap extends StatefulWidget {
  const NileDeliveryMap({
    super.key,
    required this.origin,
    required this.destination,
    this.route,
    this.height = 360,
    this.onDestinationChanged,
  });

  final GeoPlace origin;
  final GeoPlace destination;
  final RouteEstimate? route;
  final double height;
  final ValueChanged<GeoPlace>? onDestinationChanged;

  @override
  State<NileDeliveryMap> createState() => _NileDeliveryMapState();
}

class _NileDeliveryMapState extends State<NileDeliveryMap> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRoute());
  }

  @override
  void didUpdateWidget(covariant NileDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.origin.latitude != widget.origin.latitude ||
        oldWidget.origin.longitude != widget.origin.longitude ||
        oldWidget.destination.latitude != widget.destination.latitude ||
        oldWidget.destination.longitude != widget.destination.longitude ||
        oldWidget.route?.distanceKm != widget.route?.distanceKm ||
        oldWidget.route?.geometry.length != widget.route?.geometry.length;

    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRoute());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> get _routePoints => widget.route?.geometry
          .map((p) => LatLng(p[0], p[1]))
          .toList(growable: false) ??
      const <LatLng>[];

  List<LatLng> get _allPoints => <LatLng>[
        LatLng(widget.origin.latitude, widget.origin.longitude),
        LatLng(widget.destination.latitude, widget.destination.longitude),
        ..._routePoints,
      ];

  void _fitToRoute() {
    if (!mounted) return;
    final points = _allPoints;
    if (points.length < 2) return;

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(54),
        maxZoom: 16,
        minZoom: 9,
      ),
    );
  }

  void _destinationMoved(LatLng point) {
    widget.onDestinationChanged?.call(
      GeoPlace.pinned(
        latitude: point.latitude,
        longitude: point.longitude,
        name: 'Pinned delivery location',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _routePoints;
    final points = _allPoints;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center(points),
                initialZoom: _zoom(points),
                initialCameraFit: points.length >= 2
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(54),
                        maxZoom: 16,
                        minZoom: 9,
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
                  tileProvider: NetworkTileProvider(),
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
                      point: LatLng(widget.origin.latitude, widget.origin.longitude),
                      width: 44,
                      height: 44,
                      child: _pin(Icons.storefront_rounded, NileColors.primary),
                    ),
                  ],
                ),
                DragMarkers(
                  markers: [
                    DragMarker(
                      point: LatLng(widget.destination.latitude, widget.destination.longitude),
                      width: 50,
                      height: 58,
                      offset: const Offset(0, -20),
                      builder: (context, position, isDragging) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDragging)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(blurRadius: 5, color: Colors.black26),
                                ],
                              ),
                              child: const Text(
                                'Move pin',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                          Icon(
                            Icons.location_on_rounded,
                            size: 42,
                            color: NileColors.accent,
                          ),
                        ],
                      ),
                      onDragUpdate: (_, point) => _destinationMoved(point),
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
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _fitToRoute,
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      size: 18,
                      color: NileColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _statusChip(
                Icons.open_with_rounded,
                widget.onDestinationChanged == null
                    ? 'Interactive map • drag / zoom'
                    : 'Drag the customer pin to adjust',
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
            const Text(
              'Nile Tropical',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Icon(Icons.location_on_rounded, size: 16, color: NileColors.accent),
            const SizedBox(width: 5),
            const Text(
              'Customer',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
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
            Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  LatLng _center(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  double _zoom(List<LatLng> points) {
    if (points.length < 2) return 12;
    final latSpan =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b) -
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final lngSpan =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b) -
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final span = latSpan > lngSpan ? latSpan : lngSpan;
    if (span < 0.01) return 14;
    if (span < 0.03) return 12.5;
    if (span < 0.08) return 11.5;
    if (span < 0.2) return 10.5;
    return 9.5;
  }
}
