import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'api_client.dart';

/// How fast one stretch of a route is moving, Google Maps style.
enum TrafficSpeed { normal, slow, jam }

/// A run of route points sharing one [speed]: points[start..end].
@immutable
class TrafficSpan {
  const TrafficSpan({
    required this.start,
    required this.end,
    required this.speed,
  });

  final int start;
  final int end;
  final TrafficSpeed speed;
}

/// A driving route along real roads.
@immutable
class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.duration,
    this.trafficFreeDuration,
    this.traffic = const <TrafficSpan>[],
  });

  /// Road geometry from origin to destination.
  final List<LatLng> points;

  final double distanceMeters;

  /// With current traffic when the route came from Google.
  final Duration duration;

  /// The same trip on empty roads; null when the router has no traffic.
  final Duration? trafficFreeDuration;

  /// Slow and jammed stretches (and normal ones). Empty without traffic data.
  final List<TrafficSpan> traffic;

  bool get isEmpty => points.isEmpty;

  /// How much longer the traffic makes the trip, if known.
  Duration get trafficDelay {
    final Duration? free = trafficFreeDuration;
    if (free == null || duration <= free) return Duration.zero;
    return duration - free;
  }

  /// Parses `/app-api/maps/route` (Google Routes with traffic).
  static DrivingRoute? fromTrafficJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['points'] as List<dynamic>?) ?? const [];
    if (raw.length < 2) return null;
    final List<LatLng> points = raw
        .map(
          (dynamic p) =>
              LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        )
        .toList(growable: false);
    final int last = points.length - 1;
    return DrivingRoute(
      points: points,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      duration: Duration(
        seconds: ((json['durationSeconds'] as num?) ?? 0).round(),
      ),
      trafficFreeDuration: json['staticDurationSeconds'] == null
          ? null
          : Duration(seconds: (json['staticDurationSeconds'] as num).round()),
      traffic: ((json['traffic'] as List<dynamic>?) ?? const [])
          .map((dynamic t) {
            final Map<String, dynamic> m = t as Map<String, dynamic>;
            return TrafficSpan(
              start: ((m['start'] as num?) ?? 0).toInt().clamp(0, last),
              end: ((m['end'] as num?) ?? last).toInt().clamp(0, last),
              speed: switch (m['speed']) {
                'TRAFFIC_JAM' => TrafficSpeed.jam,
                'SLOW' => TrafficSpeed.slow,
                _ => TrafficSpeed.normal,
              },
            );
          })
          .where((TrafficSpan t) => t.end > t.start)
          .toList(growable: false),
    );
  }

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
          .map(
            (dynamic c) =>
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
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
/// Asks our backend first, which routes with Google and live traffic when
/// it has a key; otherwise (503, or the call fails) falls back to the public
/// OSRM demo server, which has no traffic and is rate limited.
class RouteService {
  const RouteService._();

  static const Duration _timeout = Duration(seconds: 15);

  static Uri buildOsrmUri(LatLng from, LatLng to) => Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
    '?overview=full&geometries=geojson',
  );

  static Future<DrivingRoute> fetchDrivingRoute(
    LatLng from,
    LatLng to, {
    ApiClient? api,
  }) async {
    try {
      final Map<String, dynamic> body = await (api ?? ApiClient.shared).get(
        '/maps/route',
        query: <String, String>{
          'from': '${from.latitude},${from.longitude}',
          'to': '${to.latitude},${to.longitude}',
        },
      );
      final DrivingRoute? route = DrivingRoute.fromTrafficJson(body);
      if (route != null) return route;
    } catch (e) {
      // Not configured, offline or out of quota: the free router still works.
      debugPrint('Traffic route unavailable, using OSRM: $e');
    }
    return _fetchOsrm(from, to);
  }

  static Future<DrivingRoute> _fetchOsrm(LatLng from, LatLng to) async {
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
