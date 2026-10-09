import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/models/ocpp_models.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';

void main() {
  late OcppMockService service;

  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
    service = OcppMockService.instance;
    service.clearRemoteSession();
  });

  test('no state of charge or cost is shown until the network reports one', () {
    // Regression: the dashboard greeted every driver with a 62% battery and
    // priced energy at an invented 450 ₮/kWh.
    expect(service.batteryLevel, isNull);
    expect(service.sessionCostMnt, isNull);
  });

  test('a real session brings its own numbers and leaves none behind', () {
    service.adoptRemoteSession(
      transactionId: 7,
      stationName: 'Test',
      energyKwh: 4.2,
      powerKw: 22,
      socPercent: 54,
      costMnt: 1890,
    );
    expect(service.connectorStatuses[1], ConnectorStatus.charging);
    expect(service.batteryLevel, 54);
    expect(service.sessionCostMnt, 1890);

    service.clearRemoteSession();
    expect(service.batteryLevel, isNull);
    expect(service.sessionCostMnt, isNull);
    expect(service.totalEnergyKwh, 0.0);
  });
}
