import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import 'supabase_service.dart';

class GeoPlace {
  const GeoPlace({required this.name, required this.latitude, required this.longitude});
  final String name;
  final double latitude;
  final double longitude;

  factory GeoPlace.pinned({required double latitude, required double longitude, String? name}) {
    return GeoPlace(
      name: name ?? 'Pinned delivery location',
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class RouteEstimate {
  const RouteEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    this.geometry = const [],
  });
  final double distanceKm;
  final double durationMinutes;
  /// Road-route geometry as [latitude, longitude] pairs.
  final List<List<double>> geometry;
}

class LocationSearchService {
  static const _photon = 'https://photon.komoot.io/api/';
  static const _osrm = 'https://router.project-osrm.org/route/v1/driving';

  static Future<List<GeoPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    Map<String, dynamic> json;
    if (Env.isConfigured) {
      final response = await SupabaseService.client.functions.invoke(
        'location-search',
        body: {'q': trimmed},
      );
      if (response.data is! Map) {
        throw Exception('Location search returned an invalid response.');
      }
      json = Map<String, dynamic>.from(response.data as Map);
    } else {
      final uri = Uri.parse(_photon).replace(queryParameters: {
        'q': trimmed + ', Uganda',
        'limit': '6',
        'lang': 'en',
      });
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception('Location search failed (' + response.statusCode.toString() + ').');
      json = jsonDecode(response.body) as Map<String, dynamic>;
    }
    final features = (json['features'] as List?) ?? const [];
    return features.map((raw) {
      final item = raw as Map<String, dynamic>;
      final geometry = item['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final props = (item['properties'] as Map?)?.cast<String, dynamic>() ?? {};
      final parts = <String>[
        props['name']?.toString() ?? '',
        props['street']?.toString() ?? '',
        props['city']?.toString() ?? props['county']?.toString() ?? '',
        props['state']?.toString() ?? '',
      ].where((v) => v.trim().isNotEmpty).toSet().toList();

      return GeoPlace(
        name: parts.join(', '),
        latitude: (coordinates[1] as num).toDouble(),
        longitude: (coordinates[0] as num).toDouble(),
      );
    }).where((p) => p.name.isNotEmpty).toList();
  }

  static Future<GeoPlace> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are turned off. You can search for your location instead.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Location permission was not granted. You can search for your location instead.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return GeoPlace.pinned(
      latitude: position.latitude,
      longitude: position.longitude,
      name: 'Current location',
    );
  }

  static Future<RouteEstimate> route({required GeoPlace origin, required GeoPlace destination}) async {
    Map<String, dynamic> json;
    if (Env.isConfigured) {
      final response = await SupabaseService.client.functions.invoke(
        'route',
        body: {
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      );
      if (response.data is! Map) {
        throw Exception('Route service returned an invalid response.');
      }
      json = Map<String, dynamic>.from(response.data as Map);
    } else {
      final uri = Uri.parse(
        _osrm + '/' +
        origin.longitude.toString() + ',' + origin.latitude.toString() + ';' +
        destination.longitude.toString() + ',' + destination.latitude.toString(),
      ).replace(queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      });
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('Route calculation failed (' + response.statusCode.toString() + ').');
      json = jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (json['code'] != 'Ok') throw Exception('No drivable route was found.');
    final routes = (json['routes'] as List?) ?? const [];
    if (routes.isEmpty) throw Exception('No route was found.');

    final first = routes.first as Map<String, dynamic>;
    final geometry = <List<double>>[];
    final geometryRaw = first['geometry'];
    if (geometryRaw is Map && geometryRaw['coordinates'] is List) {
      for (final point in geometryRaw['coordinates'] as List) {
        if (point is List && point.length >= 2 && point[0] is num && point[1] is num) {
          geometry.add([(point[1] as num).toDouble(), (point[0] as num).toDouble()]);
        }
      }
    }

    return RouteEstimate(
      distanceKm: (first['distance'] as num).toDouble() / 1000,
      durationMinutes: (first['duration'] as num).toDouble() / 60,
      geometry: geometry,
    );
  }
}
