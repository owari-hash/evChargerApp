import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A driving route along real roads.
@immutable
class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  /// Road geometry from origin to destination.
  final List<LatLng> points;

  final double distanceMeters;
  final Duration duration;

  bool get isEmpty => points.isEmpty;

  /// Parses an OSRM `/route/v1/driving` response.
  ///
  /// Kept separate from the network call so the parsing is testable.
  static DrivingRoute? fromOsrmJson(Map<String, dynamic> json) {
    if (json['code'] != 'Ok') return null;
    final List<dynamic> routes = (json['routes'] as List<dynamic>?) ?? const [];
    if (routes.isEmpty) return null;

    final Map<String, dynamic> first = routes.first as Map<String, dynamic>;
    final Map<String, dynamic>? geometry =
        first['geometry'] as Map<String, dynamic>?;
    final List<dynamic> coords =
        (geometry?['coordinates'] as List<dynamic>?) ?? const [];
    if (coords.isEmpty) return null;

    return DrivingRoute(
      // GeoJSON is [longitude, latitude] - the reverse of LatLng.
      points: coords
          .map((dynamic c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList(growable: false),
      distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
      duration: Duration(seconds: ((first['duration'] as num?) ?? 0).round()),
    );
  }
}

/// Thrown when a route could not be produced.
class RouteUnavailable implements Exception {
  const RouteUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'RouteUnavailable: $reason';
}

/// Fetches driving directions along real roads.
///
/// Uses the public OSRM demo server, which needs no API key. It is rate
/// limited and not intended for production traffic - swap in Mapbox
/// Directions or Google Directions (both keyed) before a public launch.
class RouteService {
  const RouteService._();

  static const Duration _timeout = Duration(seconds: 15);

  static Uri buildOsrmUri(LatLng from, LatLng to) => Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );

  static Future<DrivingRoute> fetchDrivingRoute(LatLng from, LatLng to) async {
    final http.Response response;
    try {
      response = await http.get(buildOsrmUri(from, to)).timeout(_timeout);
    } catch (e) {
      throw RouteUnavailable('network: $e');
    }

    if (response.statusCode != 200) {
      throw RouteUnavailable('HTTP ${response.statusCode}');
    }

    final DrivingRoute? route = DrivingRoute.fromOsrmJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (route == null || route.isEmpty) {
      throw const RouteUnavailable('no route in response');
    }
    return route;
  }
}
