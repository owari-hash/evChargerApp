import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/services/active_session_state.dart';

void main() {
  final ActiveSessionState session = ActiveSessionState.instance;

  setUp(session.clear);

  test('nothing is charging until the network reports a session', () {
    // Regression: the dashboard greeted every driver with a 62% battery, a
    // charge in progress and energy priced at an invented 450 ₮/kWh.
    expect(session.isCharging, isFalse);
    expect(session.socPercent, isNull);
    expect(session.costMnt, isNull);
    expect(session.powerKw, 0);
    expect(session.stationName, isNull);
  });

  test('a real session brings its own numbers and leaves none behind', () {
    session.adoptRemoteSession(
      transactionId: 7,
      stationName: 'Test',
      energyKwh: 4.2,
      powerKw: 22,
      socPercent: 54,
      costMnt: 1890,
    );
    expect(session.isCharging, isTrue);
    expect(session.socPercent, 54);
    expect(session.costMnt, 1890);
    expect(session.energyKwh, 4.2);

    session.clear();
    expect(session.isCharging, isFalse);
    expect(session.socPercent, isNull);
    expect(session.costMnt, isNull);
    expect(session.energyKwh, 0);
  });
}
