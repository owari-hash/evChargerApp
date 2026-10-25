import 'package:flutter/material.dart' show Color;

/// A connector's OCPP `connectorId` (1, 2, 3…) as the letter printed on its
/// sticker (A, B, C…) — the id itself never changes anywhere in the data or
/// API, this is display only. Falls back to the plain number past Z, which no
/// station in this network reaches (stations here have one or two
/// connectors). Mirrors `connectorLetter()` in evChargerKiosk/evChargerAdmin.
String connectorLetter(int connectorId) {
  if (connectorId < 1 || connectorId > 26) return '$connectorId';
  return String.fromCharCode(64 + connectorId);
}

/// Whether a station can be charged at right now.
///
/// The same three states the kiosk website shows, derived the same way, so a
/// pin that is amber in the browser is amber in the app.
enum StationAvailability {
  /// At least one connector is free.
  available(Color(0xFF10B981)),

  /// Online, but every connector is in use.
  busy(Color(0xFFF59E0B)),

  /// The charge point is not talking to the CSMS.
  // Red, not grey: a station that is down should read as a problem.
  offline(Color(0xFFEF4444));

  const StationAvailability(this.tone);

  /// Matches `availabilityTone()` in evChargerKiosk (Tailwind emerald-500,
  /// amber-500, slate-400).
  final Color tone;
}

/// One physical plug on a station — what the driver calls a "gun".
///
/// A station with two connectors can be available on one and occupied on the
/// other at the same time; `ChargingStationLocation.availableConnectors` is
/// only ever the count, so picking a specific gun needs this list. Mirrors
/// `StationConnector` in evChargerKiosk's `src/lib/types.ts`, built from the
/// same `/app-api/stations` response.
class StationConnector {
  const StationConnector({
    required this.connectorId,
    required this.status,
    this.type,
    this.powerKw,
    this.label,
    this.currentTransactionId,
    this.inUseByOther = false,
  });

  /// 1-based, as printed on the gun itself and on its QR sticker.
  final int connectorId;

  final String status;
  final String? type;
  final double? powerKw;

  /// An operator-set name for this gun, e.g. "A" or "Хурдан 1" — shown instead
  /// of the bare number when set.
  final String? label;

  final int? currentTransactionId;

  /// Another driver has this gun — scanned it and has it open, is starting
  /// on it, or is charging on it. Only `/stations/:id/live` reports this.
  final bool inUseByOther;

  bool get isAvailable => status == 'Available';

  /// What the driver API's own `startable()` accepts: free, or with a car
  /// already plugged in and waiting (`Preparing`).
  bool get isStartable =>
      !inUseByOther && (status == 'Available' || status == 'Preparing');
  bool get isCharging => status == 'Charging';
  bool get isFaulted => status == 'Faulted' || status == 'Unavailable';

  /// What a driver calls this gun on screen: its label if the operator set
  /// one, otherwise "Залгуур {n}".
  String displayName(String fallbackPrefix) =>
      (label != null && label!.trim().isNotEmpty)
      ? label!
      : '$fallbackPrefix ${connectorLetter(connectorId)}';

  static StationConnector? fromJson(Map<String, dynamic> json) {
    final int? connectorId = json['connectorId'] is num
        ? (json['connectorId'] as num).toInt()
        : int.tryParse(json['connectorId']?.toString() ?? '');
    if (connectorId == null) return null;

    return StationConnector(
      connectorId: connectorId,
      status: (json['status'] ?? 'Unavailable').toString(),
      type: _textOrNull(json['type']),
      powerKw: json['powerKw'] is num
          ? (json['powerKw'] as num).toDouble()
          : null,
      label: _textOrNull(json['label']),
      currentTransactionId: json['currentTransactionId'] is num
          ? (json['currentTransactionId'] as num).toInt()
          : null,
      inUseByOther: json['inUseByOther'] == true,
    );
  }

  static String? _textOrNull(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

/// A charge point as the driver sees it on the map and in the stations list.
///
/// This mirrors the `Station` shape that `/app-api/stations` returns, which the
/// kiosk builds from the CSMS charge-point records. The field names here stay
/// close to what the widgets ask for rather than to the wire format, so the
/// mapping lives in [fromJson] and nowhere else.
class ChargingStationLocation {
  const ChargingStationLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.kwSpeed,
    required this.availableConnectors,
    required this.totalConnectors,
    required this.pricePerKwh,
    required this.qrCode,
    required this.latitude,
    required this.longitude,
    this.connectorTypes = const <String>[],
    this.connectors = const <StationConnector>[],
    this.isOnline = true,
    this.feePercent = 0,
    this.baseTariffPerKwh,
    this.defaultTariffPerKwh,
    this.tariffZones = const <TariffZone>[],
  });

  final String id;
  final String name;
  final String address;

  /// Pre-formatted for display, e.g. `'0.8 км'`. Empty when the listing was
  /// fetched without an origin to measure from.
  final String distance;

  final double kwSpeed;
  final int availableConnectors;
  final int totalConnectors;

  /// What the driver pays per kWh, Eplug's service fee already included.
  final double pricePerKwh;

  /// The service fee [pricePerKwh] includes, in percent; 0 when none applies.
  final double feePercent;

  /// Base tariff per kWh before service fee markup.
  final double? baseTariffPerKwh;

  /// The rate outside every time-of-day zone.
  final double? defaultTariffPerKwh;

  /// Time-of-day rates, sorted by start; empty for a single flat rate.
  final List<TariffZone> tariffZones;

  /// Tariff to show on the UI: base price without the 1% fee markup (e.g. 1000₮ instead of 1010₮).
  double get basePricePerKwh {
    if (baseTariffPerKwh != null && baseTariffPerKwh! > 0) {
      return baseTariffPerKwh!;
    }
    if (feePercent > 0 && pricePerKwh > 0) {
      return (pricePerKwh / (1 + feePercent / 100)).roundToDouble();
    }
    return pricePerKwh;
  }

  /// What a QR code at the station encodes, and the id the start endpoint is
  /// keyed by — `/app-api/stations/<qrCode>/start`.
  final String qrCode;

  final double latitude;
  final double longitude;

  /// Plug standards this station offers, as `CONNECTOR_TYPES` codes shared with
  /// the kiosk and the CSMS: CCS2, GBT, CHAdeMO, Type2, Type1, Schuko.
  final List<String> connectorTypes;

  /// Every physical gun on this station, each with its own live status — a
  /// station showing "1/2 available" has one of these free and one occupied,
  /// and this is the only place that distinction is readable.
  final List<StationConnector> connectors;

  /// False when the CSMS has lost contact with the charge point. An offline
  /// station still belongs on the map — a driver heading for one deserves to
  /// know it is dark rather than to find out on arrival.
  final bool isOnline;

  /// How this station reads on the map: offline first — a charge point that is
  /// not connected cannot be charged at whatever its last connector counts
  /// said — then free connectors, then busy.
  StationAvailability get availability {
    if (!isOnline) return StationAvailability.offline;
    if (availableConnectors > 0) return StationAvailability.available;
    return StationAvailability.busy;
  }

  /// Bounding box the network operates in: Mongolia plus a wide margin over
  /// its neighbours, so a border site or a slightly-off survey still maps.
  ///
  /// This exists because the CSMS accepts charge points with unset or
  /// placeholder coordinates, and one such record — latitude 1, longitude 2,
  /// which is open ocean off West Africa — is enough to drag the map off the
  /// country and make the nearest-station search meaningless. Widen these
  /// bounds if the network ever runs outside them.
  static const double minLatitude = 38.0;
  static const double maxLatitude = 56.0;
  static const double minLongitude = 84.0;
  static const double maxLongitude = 124.0;

  /// True when [latitude]/[longitude] could plausibly be a station on this
  /// network. See [minLatitude] for why this check exists.
  static bool isInServiceArea(double latitude, double longitude) {
    return latitude >= minLatitude &&
        latitude <= maxLatitude &&
        longitude >= minLongitude &&
        longitude <= maxLongitude;
  }

  /// Builds a station from one `/app-api/stations` entry.
  ///
  /// Returns null when the record carries no coordinates, or coordinates
  /// outside [isInServiceArea]. Such a charge point cannot be placed on the map
  /// or distance-sorted, and showing it in the list with a blank or nonsense
  /// location reads as a bug rather than as missing data.
  static ChargingStationLocation? fromJson(Map<String, dynamic> json) {
    final double? latitude = _toDouble(json['latitude']);
    final double? longitude = _toDouble(json['longitude']);
    if (latitude == null || longitude == null) return null;

    if (!isInServiceArea(latitude, longitude)) return null;

    final String id = (json['id'] ?? '').toString();
    if (id.isEmpty) return null;

    final double? distanceKm = _toDouble(json['distanceKm']);

    return ChargingStationLocation(
      id: id,
      name: (json['name'] ?? '').toString().trim().isEmpty
          ? id
          : json['name'].toString(),
      address: (json['address'] ?? json['description'] ?? '').toString(),
      distance: distanceKm == null ? '' : formatDistance(distanceKm),
      kwSpeed: _toDouble(json['maxPowerKw']) ?? 0,
      availableConnectors: _toInt(json['availableConnectors']) ?? 0,
      totalConnectors: _toInt(json['totalConnectors']) ?? 0,
      pricePerKwh: _toDouble(json['tariffPerKwh']) ?? 0,
      qrCode: id,
      latitude: latitude,
      longitude: longitude,
      connectorTypes: (json['connectorTypes'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic type) => type.toString())
          .where((String type) => type.isNotEmpty)
          .toList(growable: false),
      connectors: (json['connectors'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StationConnector.fromJson)
          .whereType<StationConnector>()
          .toList(growable: false),
      isOnline: json['isOnline'] != false,
      feePercent: _toDouble(json['feePercent']) ?? 0,
      baseTariffPerKwh: _toDouble(json['baseTariffPerKwh']),
      defaultTariffPerKwh: _toDouble(json['defaultTariffPerKwh']),
      tariffZones: (json['tariffZones'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TariffZone.fromJson)
          .whereType<TariffZone>()
          .toList(growable: false),
    );
  }

  /// Metres below a kilometre, so a station across the street does not read as
  /// `0.1 км`.
  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} м';
    return '${km.toStringAsFixed(1)} км';
  }

  ChargingStationLocation copyWith({String? distance}) {
    return ChargingStationLocation(
      id: id,
      name: name,
      address: address,
      distance: distance ?? this.distance,
      kwSpeed: kwSpeed,
      availableConnectors: availableConnectors,
      totalConnectors: totalConnectors,
      pricePerKwh: pricePerKwh,
      qrCode: qrCode,
      latitude: latitude,
      longitude: longitude,
      connectorTypes: connectorTypes,
      connectors: connectors,
      isOnline: isOnline,
      feePercent: feePercent,
      baseTariffPerKwh: baseTariffPerKwh,
      defaultTariffPerKwh: defaultTariffPerKwh,
      tariffZones: tariffZones,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// A time-of-day rate. Minutes are Mongolia local time since midnight.
class TariffZone {
  const TariffZone({
    required this.startMinute,
    required this.endMinute,
    required this.tariffPerKwh,
    this.name,
  });

  final String? name;
  final int startMinute;
  final int endMinute;
  final double tariffPerKwh;

  /// Whether this zone covers [minute] (minutes since local midnight).
  bool covers(int minute) => minute >= startMinute && minute < endMinute;

  static TariffZone? fromJson(Map<String, dynamic> json) {
    final dynamic start = json['startMinute'];
    final dynamic end = json['endMinute'];
    final dynamic rate = json['tariffPerKwh'];
    if (start is! num || end is! num || rate is! num) return null;
    final String name = (json['name'] ?? '').toString().trim();
    return TariffZone(
      name: name.isEmpty ? null : name,
      startMinute: start.toInt(),
      endMinute: end.toInt(),
      tariffPerKwh: rate.toDouble(),
    );
  }
}
