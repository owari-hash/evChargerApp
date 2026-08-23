import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/station.dart';
import 'api_client.dart';

/// The live charging network, from `/app-api/stations`.
///
/// The app used to ship a hardcoded list of five Ulaanbaatar stations, which
/// meant the map showed the same five whatever the operator had actually
/// commissioned, at prices that were frozen at build time. This asks the CSMS
/// instead, by way of the driver API the kiosk already serves.
///
/// The list is held on the singleton so the map, the stations tab and the
/// dashboard all render the same network: whichever screen loads first pays for
/// the fetch, and [stations] is a [ValueListenable] the others rebuild against.
class StationsService {
  StationsService({ApiClient? client}) : _client = client ?? ApiClient.shared;

  static final StationsService instance = StationsService();

  final ApiClient _client;

  /// Last-known network. Starts at the offline fallback so the first frame has
  /// something to draw, and is replaced the moment a fetch lands.
  final ValueNotifier<List<ChargingStationLocation>> stations =
      ValueNotifier<List<ChargingStationLocation>>(fallbackStations);

  /// True while a fetch is in flight, for the screens that show a spinner.
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  /// Set when the last fetch failed, so a screen can say the list may be stale
  /// rather than quietly presenting cached stations as live.
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  /// True while [stations] is the built-in fallback rather than live data.
  bool get isFallback => _isFallback;
  bool _isFallback = true;

  Future<void>? _inFlight;

  /// Fetches the network, at most once at a time.
  ///
  /// [latitude] and [longitude] let the API sort by distance and fill in
  /// `distanceKm`; without them the list comes back sorted by availability and
  /// name, with no distances shown.
  Future<List<ChargingStationLocation>> load({
    double? latitude,
    double? longitude,
    bool force = false,
  }) async {
    if (_inFlight != null && !force) {
      await _inFlight;
      return stations.value;
    }

    final Future<void> fetch = _fetch(latitude: latitude, longitude: longitude);
    _inFlight = fetch;
    try {
      await fetch;
    } finally {
      if (identical(_inFlight, fetch)) _inFlight = null;
    }
    return stations.value;
  }

  Future<void> _fetch({double? latitude, double? longitude}) async {
    loading.value = true;
    try {
      final Map<String, String> query = <String, String>{'limit': '200'};
      if (latitude != null && longitude != null) {
        query['lat'] = latitude.toStringAsFixed(6);
        query['lng'] = longitude.toStringAsFixed(6);
      }

      final Map<String, dynamic> body = await _client.get(
        '/stations',
        query: query,
      );

      final List<ChargingStationLocation> parsed =
          (body['stations'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ChargingStationLocation.fromJson)
              .whereType<ChargingStationLocation>()
              .toList(growable: false);

      // An empty network is a real answer, but replacing the map with nothing
      // on the strength of it would leave the driver staring at blank tiles.
      // Keep what is on screen and say so instead.
      if (parsed.isEmpty) {
        error.value = 'Одоогоор нээлттэй станц олдсонгүй.';
        return;
      }

      stations.value = parsed;
      _isFallback = false;
      error.value = null;
    } on ApiException catch (err) {
      error.value = err.message;
    } finally {
      loading.value = false;
    }
  }

  /// Recomputes the display distances against a new origin, without refetching.
  ///
  /// The GPS stream moves faster than it is worth asking the server to re-sort,
  /// so the map updates the numbers locally between loads.
  void reprojectDistances({
    required double latitude,
    required double longitude,
  }) {
    if (stations.value.isEmpty) return;
    stations.value = stations.value
        .map(
          (ChargingStationLocation station) => station.copyWith(
            distance: ChargingStationLocation.formatDistance(
              haversineKm(
                latitude,
                longitude,
                station.latitude,
                station.longitude,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  /// Great-circle distance in kilometres.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _radians(lat2 - lat1);
    final double dLon = _radians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  /// Shown only when the network cannot be reached — an empty map is worse than
  /// a stale one, and every screen labels these as unverified.
  static const List<ChargingStationLocation> fallbackStations =
      <ChargingStationLocation>[
        ChargingStationLocation(
          id: 'UB-001',
          name: 'Шангри-Ла Молл Цэнэглэгч',
          address: 'Улаанбаатар, Сүхбаатар дүүрэг, 1-р хороо',
          distance: '0.8 км',
          kwSpeed: 180.0,
          availableConnectors: 3,
          totalConnectors: 4,
          pricePerKwh: 450.0,
          qrCode: 'EV-UB-SHANGRILA',
          latitude: 47.9150,
          longitude: 106.9205,
          connectorTypes: <String>['CCS2', 'Type2', 'GBT'],
        ),
        ChargingStationLocation(
          id: 'UB-002',
          name: 'Зайсан Хилл Цогцолбор',
          address: 'Улаанбаатар, Хан-Уул дүүрэг, 11-р хороо',
          distance: '2.4 км',
          kwSpeed: 120.0,
          availableConnectors: 2,
          totalConnectors: 4,
          pricePerKwh: 420.0,
          qrCode: 'EV-UB-ZAISAN',
          latitude: 47.8864,
          longitude: 106.9058,
          connectorTypes: <String>['CCS2', 'GBT', 'CHAdeMO'],
        ),
        ChargingStationLocation(
          id: 'UB-003',
          name: 'Улсын Их Дэлгүүр Станц',
          address: 'Улаанбаатар, Чингэлтэй дүүрэг, 3-р хороо',
          distance: '1.1 км',
          kwSpeed: 60.0,
          availableConnectors: 4,
          totalConnectors: 6,
          pricePerKwh: 380.0,
          qrCode: 'EV-UB-DEPTSTORE',
          latitude: 47.9171,
          longitude: 106.9068,
          connectorTypes: <String>['Type2', 'GBT', 'Schuko'],
        ),
        ChargingStationLocation(
          id: 'UB-004',
          name: 'Үндэсний Цэцэрлэгт Хүрээлэн',
          address: 'Улаанбаатар, Баянзүрх дүүрэг, 26-р хороо',
          distance: '3.5 км',
          kwSpeed: 150.0,
          availableConnectors: 4,
          totalConnectors: 4,
          pricePerKwh: 400.0,
          qrCode: 'EV-UB-NATIONALPARK',
          latitude: 47.9080,
          longitude: 106.9450,
          connectorTypes: <String>['CCS2', 'CHAdeMO', 'Type2'],
        ),
        ChargingStationLocation(
          id: 'UB-005',
          name: 'Сүхбаатарын Талбай Станц',
          address: 'Улаанбаатар, Сүхбаатар дүүрэг, Төв талбай',
          distance: '0.3 км',
          kwSpeed: 200.0,
          availableConnectors: 2,
          totalConnectors: 4,
          pricePerKwh: 480.0,
          qrCode: 'EV-UB-SUKHBAATAR',
          latitude: 47.9188,
          longitude: 106.9176,
          connectorTypes: <String>['CCS2', 'Type2', 'CHAdeMO', 'GBT'],
        ),
      ];
}
