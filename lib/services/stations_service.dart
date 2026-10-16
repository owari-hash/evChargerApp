import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/station.dart';
import '../utils/app_strings.dart';
import 'api_client.dart';

/// What a station/connector QR sticker resolves to — enough to pre-select the
/// right gun without the driver ever typing a station name.
class ConnectorLookup {
  const ConnectorLookup({
    required this.stationId,
    required this.stationName,
    this.address,
    this.connectorId,
    this.connectorType,
    this.powerKw,
    this.label,
  });

  final String stationId;
  final String stationName;
  final String? address;
  final int? connectorId;
  final String? connectorType;
  final double? powerKw;
  final String? label;

  static ConnectorLookup? fromJson(Map<String, dynamic> json) {
    final String stationId = (json['stationId'] ?? '').toString();
    if (stationId.isEmpty) return null;
    return ConnectorLookup(
      stationId: stationId,
      stationName: (json['stationName'] ?? '').toString(),
      address: _textOrNull(json['address']),
      connectorId: json['connectorId'] is num
          ? (json['connectorId'] as num).toInt()
          : null,
      connectorType: _textOrNull(json['connectorType']),
      powerKw: json['powerKw'] is num ? (json['powerKw'] as num).toDouble() : null,
      label: _textOrNull(json['label']),
    );
  }

  static String? _textOrNull(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

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

  /// Last-known live network. Empty until the first fetch lands; a failed
  /// fetch keeps whatever was already here and sets [error] instead.
  ///
  /// It used to start on five invented Ulaanbaatar stations, with made-up
  /// prices and free plugs, which offline drivers could not tell from the
  /// real thing.
  final ValueNotifier<List<ChargingStationLocation>> stations =
      ValueNotifier<List<ChargingStationLocation>>(
        const <ChargingStationLocation>[],
      );

  /// True while a fetch is in flight, for the screens that show a spinner.
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  /// Set when the last fetch failed, so a screen can say the list may be stale
  /// rather than quietly presenting cached stations as live.
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

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
      error.value = null;
    } on ApiException catch (err) {
      error.value = err.message;
    } finally {
      loading.value = false;
    }
  }

  /// Resolves a connector's QR short code (e.g. `7PZJYJ`, however it reached
  /// here — a raw code or the full `eplug.mn/c/<code>` sticker URL) to the
  /// station and gun it belongs to. Unauthenticated on the server, so this
  /// works before the driver has signed in.
  Future<ConnectorLookup> resolveConnectorCode(String raw) async {
    final String code = _extractCode(raw);
    if (code.isEmpty) {
      throw const ApiException(statusCode: 400, message: 'Энэ QR кодыг танисангүй.');
    }
    final Map<String, dynamic> body = await _client.get(
      '/app/connector/${Uri.encodeComponent(code)}',
    );
    final ConnectorLookup? lookup = ConnectorLookup.fromJson(body);
    if (lookup == null) {
      throw const ApiException(statusCode: 404, message: 'Энэ код олдсонгүй');
    }
    return lookup;
  }

  /// A scanned QR encodes the sticker's full link; the short code is its last
  /// path segment. A code typed or pasted in directly has no slashes at all.
  static String _extractCode(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed;
  }

  /// One station's live detail — tariff, connectors, everything the confirm
  /// card shows before the driver commits to starting a charge there.
  Future<ChargingStationLocation> station(String stationId) async {
    final Map<String, dynamic> body = await _client.get(
      '/stations/${Uri.encodeComponent(stationId)}',
    );
    final ChargingStationLocation? station = ChargingStationLocation.fromJson(
      (body['station'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
    if (station == null) {
      throw const ApiException(statusCode: 404, message: 'Станц олдсонгүй.');
    }
    return station;
  }

  /// Live connector states for one station, from `/stations/:id/live` —
  /// lighter than [station], for refreshing an open station sheet.
  Future<List<StationConnector>> liveConnectors(String stationId) async {
    final Map<String, dynamic> body = await _client.get(
      '/stations/${Uri.encodeComponent(stationId)}/live',
    );
    return (body['connectors'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(StationConnector.fromJson)
        .whereType<StationConnector>()
        .toList(growable: false);
  }

  /// Asks the charge point to begin a session over OCPP, on the signed-in
  /// driver's own charge tag. The station's own Authorize decides whether that
  /// tag can actually charge there — a wallet top-up, a Client-sponsored free
  /// card, or a plain refusal all come back as the same `ApiException`.
  ///
  /// The charge point answers RemoteStartTransaction with `Accepted` or
  /// `Rejected`. Anything but `Accepted` — a missing status included — is
  /// thrown as an [ApiException]: it used to be reported as "charge started"
  /// while nothing was charging.
  Future<void> startCharging(String stationId, {int? connectorId}) async {
    final Map<String, dynamic> body = await _client.post(
      '/stations/${Uri.encodeComponent(stationId)}/start',
      body: connectorId != null ? <String, dynamic>{'connectorId': connectorId} : null,
    );
    final String status = (body['status'] ?? '').toString();
    if (status != 'Accepted') {
      throw ApiException(
        statusCode: 409,
        message: AppStrings.get('start_rejected'),
      );
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
}
