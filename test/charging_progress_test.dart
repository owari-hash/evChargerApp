import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/models/ocpp_models.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';

void main() {
  late OcppMockService service;

  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
    service = OcppMockService.instance;
    service.batteryLevel = 62.0;
    service.targetLimitPct = 75.0;
    service.totalEnergyKwh = 18.5;
    service.connectorStatuses[1] = ConnectorStatus.charging;
  });

  /// Mirrors one telemetry tick.
  void tick() {
    if (service.connectorStatuses[1] == ConnectorStatus.charging) {
      if (service.batteryLevel < service.targetLimitPct) {
        service.batteryLevel = service.batteryLevel + 0.15 > service.targetLimitPct
            ? service.targetLimitPct
            : service.batteryLevel + 0.15;
        service.remainingKm = service.batteryLevel * 1.58;
        service.totalEnergyKwh += 0.02;
      }
    }
  }

  test('battery and cost only ever rise while charging', () {
    double lastBattery = service.batteryLevel;
    double lastCost = service.totalEnergyKwh * 450;

    for (int i = 0; i < 50; i++) {
      tick();
      expect(service.batteryLevel, greaterThanOrEqualTo(lastBattery));
      expect(service.totalEnergyKwh * 450, greaterThanOrEqualTo(lastCost));
      lastBattery = service.batteryLevel;
      lastCost = service.totalEnergyKwh * 450;
    }
    expect(service.batteryLevel, greaterThan(62.0));
  });

  test('lowering the target below the charge never drains the battery', () {
    // Regression: dragging the limit to 50% snapped a 62% battery down to 50%.
    service.targetLimitPct = 50.0;
    final double before = service.batteryLevel;
    final double kmBefore = service.remainingKm;

    for (int i = 0; i < 10; i++) {
      tick();
    }

    expect(service.batteryLevel, before);
    expect(service.remainingKm, kmBefore);
  });

  test('charging stops accruing cost once the target is reached', () {
    service.targetLimitPct = 62.3;
    for (int i = 0; i < 40; i++) {
      tick();
    }
    final double settled = service.totalEnergyKwh;
    for (int i = 0; i < 10; i++) {
      tick();
    }
    expect(service.totalEnergyKwh, settled);
    expect(service.batteryLevel, closeTo(62.3, 0.001));
  });
}
