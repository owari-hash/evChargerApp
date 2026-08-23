/// One charging session, mirroring `ChargingSession` in evChargerKiosk's
/// `src/lib/types.ts`.
///
/// Sessions are keyed to the charge tags linked to the account, which is why an
/// account with no tag simply has no history yet.
class ChargingSession {
  const ChargingSession({
    required this.transactionId,
    required this.chargePointId,
    required this.connectorId,
    required this.idTag,
    required this.status,
    required this.energyKwh,
    this.stationName,
    this.startTimestamp,
    this.stopTimestamp,
    this.cost,
    this.lastPowerW,
    this.lastSocPercent,
    this.stopReason,
  });

  final int transactionId;
  final String chargePointId;
  final String? stationName;
  final int connectorId;
  final String idTag;
  final SessionStatus status;
  final DateTime? startTimestamp;
  final DateTime? stopTimestamp;
  final num energyKwh;
  final num? cost;
  final num? lastPowerW;
  final num? lastSocPercent;
  final String? stopReason;

  bool get isActive => status == SessionStatus.active;

  /// Where the session happened, preferring the station's name over its id.
  String get displayLocation => (stationName != null && stationName!.isNotEmpty)
      ? stationName!
      : chargePointId;

  /// How long it ran — to now while still charging.
  Duration? get duration {
    if (startTimestamp == null) return null;
    final DateTime end = stopTimestamp ?? DateTime.now();
    final Duration span = end.difference(startTimestamp!);
    return span.isNegative ? Duration.zero : span;
  }

  factory ChargingSession.fromJson(Map<String, dynamic> json) {
    return ChargingSession(
      transactionId: json['transactionId'] is num
          ? (json['transactionId'] as num).toInt()
          : 0,
      chargePointId: (json['chargePointId'] ?? '').toString(),
      stationName: _text(json['stationName']),
      connectorId: json['connectorId'] is num
          ? (json['connectorId'] as num).toInt()
          : 0,
      idTag: (json['idTag'] ?? '').toString(),
      status: _status((json['status'] ?? '').toString()),
      startTimestamp: _date(json['startTimestamp']),
      stopTimestamp: _date(json['stopTimestamp']),
      energyKwh: json['energyKwh'] is num ? json['energyKwh'] as num : 0,
      cost: json['cost'] is num ? json['cost'] as num : null,
      lastPowerW: json['lastPowerW'] is num ? json['lastPowerW'] as num : null,
      lastSocPercent: json['lastSocPercent'] is num
          ? json['lastSocPercent'] as num
          : null,
      stopReason: _text(json['stopReason']),
    );
  }

  static SessionStatus _status(String raw) {
    switch (raw.toLowerCase()) {
      case 'active':
        return SessionStatus.active;
      case 'rejected':
        return SessionStatus.rejected;
      default:
        return SessionStatus.completed;
    }
  }

  static String? _text(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) {
    final String? text = _text(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}

enum SessionStatus { active, completed, rejected }
