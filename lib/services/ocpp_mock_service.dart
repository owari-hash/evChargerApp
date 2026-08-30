import 'dart:async';
import 'dart:math';
import '../models/ocpp_models.dart';
import '../models/station.dart';
import 'stations_service.dart';

class OcppMockService {
  static final OcppMockService instance = OcppMockService._internal();
  OcppMockService._internal() {
    _startTelemetryTimer();
  }

  // System State Variables
  bool isConnected = true;
  String chargePointId = 'CP-UB-EPLUG-001';
  int activeTransactionId = 10042;
  double batteryLevel = 62.0; // %
  double remainingKm = 98.0; // km
  // Idle until a session actually starts. These used to hold demo values, so
  // every driver saw a charge in progress the moment they signed in.
  double activePowerKw = 0.0; // kW
  double totalEnergyKwh = 0.0; // kWh
  double targetLimitPct = 75.0;
  bool isPlugLocked = true;
  bool isDarkTheme = false;

  // Active Session info
  String? activeStationName;
  String? activeQrCode;
  DateTime? sessionStartTime;

  Map<int, ConnectorStatus> connectorStatuses = {
    0: ConnectorStatus.available,
    1: ConnectorStatus.available,
    2: ConnectorStatus.available,
  };

  /// Mirrors a session the driver API reports as running onto the local view,
  /// so the dashboard shows the real charge rather than a demo one.
  ///
  /// Takes plain values rather than the API model to keep this service free of
  /// any dependency on the driver API layer.
  void adoptRemoteSession({
    required int transactionId,
    required String stationName,
    required double energyKwh,
    required double powerKw,
    double? socPercent,
  }) {
    activeTransactionId = transactionId;
    activeStationName = stationName;
    totalEnergyKwh = energyKwh;
    activePowerKw = powerKw;
    if (socPercent != null && socPercent > 0) batteryLevel = socPercent;
    connectorStatuses[1] = ConnectorStatus.charging;
  }

  /// Nothing is charging: drop anything left over from an earlier session so
  /// the dashboard shows its idle state.
  void clearRemoteSession() {
    activeStationName = null;
    activeQrCode = null;
    sessionStartTime = null;
    totalEnergyKwh = 0.0;
    activePowerKw = 0.0;
    connectorStatuses[1] = ConnectorStatus.available;
  }

  /// The live network, owned by [StationsService].
  ///
  /// Kept here so the screens that grew up reading it off this service keep
  /// working; the stations themselves are no longer invented locally.
  List<ChargingStationLocation> get nearbyStations =>
      StationsService.instance.stations.value;

  // Log History
  final List<OcppFrame> _logHistory = [];
  final StreamController<List<OcppFrame>> _logStreamController =
      StreamController<List<OcppFrame>>.broadcast();

  final StreamController<Map<String, dynamic>> _telemetryStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _telemetryTimer;

  List<OcppFrame> get logs => List.unmodifiable(_logHistory);
  Stream<List<OcppFrame>> get logStream => _logStreamController.stream;
  Stream<Map<String, dynamic>> get telemetryStream =>
      _telemetryStreamController.stream;

  static bool enablePeriodicTimer = true;

  void _startTelemetryTimer() {
    if (!enablePeriodicTimer) return;
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (connectorStatuses[1] == ConnectorStatus.charging) {
        // Charging only ever adds. Lowering the target below the current level
        // used to clamp the battery *downwards*, so the charge and the range
        // fell while the session bill kept climbing.
        if (batteryLevel < targetLimitPct) {
          batteryLevel = min(targetLimitPct, batteryLevel + 0.15);
          remainingKm = batteryLevel * 1.58;
          totalEnergyKwh += 0.02;
        }

        _telemetryStreamController.add({
          'batteryLevel': batteryLevel,
          'remainingKm': remainingKm,
          'powerKw': activePowerKw,
          'totalEnergyKwh': totalEnergyKwh,
          'status': connectorStatuses[1]?.code ?? 'Charging',
        });
      }
    });
  }

  void addLog(OcppFrame frame) {
    _logHistory.insert(0, frame);
    if (_logHistory.length > 200) {
      _logHistory.removeLast();
    }
    _logStreamController.add(_logHistory);
  }

  void clearLogs() {
    _logHistory.clear();
    _logStreamController.add(_logHistory);
  }

  Future<bool> startSessionFromQrCode(
    String qrCode,
    double amountPaidMnt,
  ) async {
    activeQrCode = qrCode;
    sessionStartTime = DateTime.now();

    final station = nearbyStations.firstWhere(
      (s) => s.qrCode == qrCode,
      orElse: () => nearbyStations.first,
    );
    activeStationName = station.name;

    await executeOcppAction('Authorize', {'idTag': 'USER_QR_TAG_$qrCode'});

    final response = await executeOcppAction('StartTransaction', {
      'connectorId': 1,
      'idTag': 'USER_QR_TAG_$qrCode',
      'meterStart': (totalEnergyKwh * 1000).toInt(),
      'timestamp': sessionStartTime!.toIso8601String(),
    });

    connectorStatuses[1] = ConnectorStatus.charging;
    _telemetryStreamController.add({
      'batteryLevel': batteryLevel,
      'remainingKm': remainingKm,
      'powerKw': activePowerKw,
      'totalEnergyKwh': totalEnergyKwh,
      'status': 'Charging',
    });

    return response.messageTypeId == OcppMessageType.callResult;
  }

  Future<void> stopUserChargingSession() async {
    await executeOcppAction('StopTransaction', {
      'transactionId': activeTransactionId,
      'idTag': activeQrCode != null ? 'USER_QR_TAG_$activeQrCode' : 'USER_APP',
      'meterStop': (totalEnergyKwh * 1000).toInt(),
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'Local',
    });

    connectorStatuses[1] = ConnectorStatus.finishing;
    activeStationName = null;
    Future.delayed(const Duration(seconds: 2), () {
      connectorStatuses[1] = ConnectorStatus.available;
    });
  }

  Future<OcppFrame> executeOcppAction(
    String action,
    Map<String, dynamic> requestPayload,
  ) async {
    final String msgId = 'MSG-${DateTime.now().millisecondsSinceEpoch}';

    final callFrame = OcppFrame.call(
      messageId: msgId,
      action: action,
      payload: requestPayload,
    );
    addLog(callFrame);

    await Future.delayed(const Duration(milliseconds: 200));

    Map<String, dynamic> responsePayload = {};

    switch (action) {
      case 'Authorize':
        responsePayload = {
          'idTagInfo': {
            'status': 'Accepted',
            'expiryDate': DateTime.now()
                .add(const Duration(days: 365))
                .toIso8601String(),
          },
        };
        break;

      case 'StartTransaction':
        activeTransactionId++;
        connectorStatuses[1] = ConnectorStatus.charging;
        responsePayload = {
          'transactionId': activeTransactionId,
          'idTagInfo': {'status': 'Accepted'},
        };
        break;

      case 'StopTransaction':
        connectorStatuses[1] = ConnectorStatus.finishing;
        Future.delayed(const Duration(seconds: 2), () {
          connectorStatuses[1] = ConnectorStatus.available;
        });
        responsePayload = {
          'idTagInfo': {'status': 'Accepted'},
        };
        break;

      default:
        responsePayload = {'status': 'Accepted'};
    }

    final responseFrame = OcppFrame.callResult(
      messageId: msgId,
      action: action,
      payload: responsePayload,
    );

    addLog(responseFrame);
    return responseFrame;
  }

  void toggleCharging() {
    if (connectorStatuses[1] == ConnectorStatus.charging) {
      stopUserChargingSession();
    } else {
      startSessionFromQrCode('EV-UB-SHANGRILA', 25000.0);
    }
  }

  void toggleLock() {
    if (isPlugLocked) {
      executeOcppAction('UnlockConnector', {'connectorId': 1});
    } else {
      isPlugLocked = true;
    }
  }

  void dispose() {
    _telemetryTimer?.cancel();
    _logStreamController.close();
    _telemetryStreamController.close();
  }
}
