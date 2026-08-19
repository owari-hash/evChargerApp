import 'dart:async';
import 'dart:math';
import '../models/ocpp_models.dart';

class ChargingStationLocation {
  final String id;
  final String name;
  final String address;
  final String distance;
  final double kwSpeed;
  final int availableConnectors;
  final int totalConnectors;
  final double pricePerKwh;
  final String qrCode;
  final double latitude;
  final double longitude;

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
  });
}

class OcppMockService {
  static final OcppMockService instance = OcppMockService._internal();
  OcppMockService._internal() {
    _startTelemetryTimer();
  }

  // System State Variables
  bool isConnected = true;
  String chargePointId = 'CP-UB-ZEV-001';
  int activeTransactionId = 10042;
  double batteryLevel = 62.0; // %
  double remainingKm = 98.0; // km
  double activePowerKw = 180.0; // kW
  double totalEnergyKwh = 18.5; // kWh
  double targetLimitPct = 75.0;
  bool isPlugLocked = true;
  bool isDarkTheme = false;

  // Active Session info
  String? activeStationName;
  String? activeQrCode;
  DateTime? sessionStartTime;

  Map<int, ConnectorStatus> connectorStatuses = {
    0: ConnectorStatus.available,
    1: ConnectorStatus.charging,
    2: ConnectorStatus.available,
  };

  // Real Charging Stations in Ulaanbaatar, Mongolia (Exact Lat/Lng)
  final List<ChargingStationLocation> nearbyStations = const [
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
    ),
  ];

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

  Future<bool> startSessionFromQrCode(String qrCode, double amountPaidMnt) async {
    activeQrCode = qrCode;
    sessionStartTime = DateTime.now();

    final station = nearbyStations.firstWhere(
      (s) => s.qrCode == qrCode,
      orElse: () => nearbyStations.first,
    );
    activeStationName = station.name;

    await executeOcppAction('Authorize', {
      'idTag': 'USER_QR_TAG_$qrCode',
    });

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
            'expiryDate': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
          }
        };
        break;

      case 'StartTransaction':
        activeTransactionId++;
        connectorStatuses[1] = ConnectorStatus.charging;
        responsePayload = {
          'transactionId': activeTransactionId,
          'idTagInfo': {'status': 'Accepted'}
        };
        break;

      case 'StopTransaction':
        connectorStatuses[1] = ConnectorStatus.finishing;
        Future.delayed(const Duration(seconds: 2), () {
          connectorStatuses[1] = ConnectorStatus.available;
        });
        responsePayload = {
          'idTagInfo': {'status': 'Accepted'}
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
