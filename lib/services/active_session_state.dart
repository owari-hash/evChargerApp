/// The charge running on the driver's account, exactly as the driver API last
/// reported it — and nothing when it reported none.
///
/// This replaces `OcppMockService`, which simulated a charge point (invented
/// OCPP frames, a fake transaction counter, a pretend plug lock) next to the
/// real data. Only the real half is left: the dashboard copies the running
/// session in with [adoptRemoteSession] and drops it with [clear].
class ActiveSessionState {
  ActiveSessionState._();

  static final ActiveSessionState instance = ActiveSessionState._();

  /// The running session's transaction, or null when nothing is charging.
  int? transactionId;

  String? stationName;

  /// The car's own state of charge, only if the station passed one on.
  double? socPercent;

  /// Backend's estimate of minutes to a full battery, when it can make one.
  int? minutesToFull;
  double powerKw = 0;
  double energyKwh = 0;

  /// What the network has billed so far, when it says.
  double? costMnt;

  bool get isCharging => transactionId != null;

  void adoptRemoteSession({
    required int transactionId,
    required String stationName,
    required double energyKwh,
    required double powerKw,
    double? socPercent,
    int? minutesToFull,
    double? costMnt,
  }) {
    this.minutesToFull = minutesToFull;
    this.transactionId = transactionId;
    this.stationName = stationName;
    this.energyKwh = energyKwh;
    this.powerKw = powerKw;
    this.costMnt = costMnt;
    // A station that stops reporting the charge keeps the last real reading
    // rather than dropping back to "unknown" for a poll.
    if (socPercent != null && socPercent > 0) this.socPercent = socPercent;
  }

  void clear() {
    transactionId = null;
    stationName = null;
    socPercent = null;
    minutesToFull = null;
    powerKw = 0;
    energyKwh = 0;
    costMnt = null;
  }
}
