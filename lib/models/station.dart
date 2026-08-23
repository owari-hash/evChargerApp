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
    this.isOnline = true,
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
  final double pricePerKwh;

  /// What a QR code at the station encodes, and the id the start endpoint is
  /// keyed by — `/app-api/stations/<qrCode>/start`.
  final String qrCode;

  final double latitude;
  final double longitude;

  /// Plug standards this station offers, as `CONNECTOR_TYPES` codes shared with
  /// the kiosk and the CSMS: CCS2, GBT, CHAdeMO, Type2, Type1, Schuko.
  final List<String> connectorTypes;

  /// False when the CSMS has lost contact with the charge point. An offline
  /// station still belongs on the map — a driver heading for one deserves to
  /// know it is dark rather than to find out on arrival.
  final bool isOnline;

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
      isOnline: json['isOnline'] != false,
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
      isOnline: isOnline,
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
