import 'dart:convert';
import 'package:http/http.dart' as http;

class GeoPlace {
  const GeoPlace({required this.name, required this.latitude, required this.longitude});
  final String name;
  final double latitude;
  final double longitude;
}

class RouteEstimate {
  const RouteEstimate({required this.distanceKm, required this.durationMinutes});
  final double distanceKm;
  final double durationMinutes;
}

class LocationSearchService {
  static const _photon = 'https://photon.komoot.io/api/';
  static const _osrm = 'https://router.project-osrm.org/route/v1/driving';

  static Future<List<GeoPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final uri = Uri.parse(_photon).replace(queryParameters: {
      'q': '${trimmed}, Uganda',
      'limit': '6',
      'lang': 'en',
    });

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('Location search failed (${response.statusCode}).');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
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

  static Future<RouteEstimate> route({required GeoPlace origin, required GeoPlace destination}) async {
    final uri = Uri.parse(
      '$_osrm/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
    ).replace(queryParameters: {'overview': 'false', 'steps': 'false'});

    final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Route calculation failed (${response.statusCode}).');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 'Ok') throw Exception('No drivable route was found.');
    final routes = (json['routes'] as List?) ?? const [];
    if (routes.isEmpty) throw Exception('No route was found.');

    final first = routes.first as Map<String, dynamic>;
    return RouteEstimate(
      distanceKm: (first['distance'] as num).toDouble() / 1000,
      durationMinutes: (first['duration'] as num).toDouble() / 60,
    );
  }
}
