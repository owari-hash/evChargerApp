import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/models/station.dart';
import 'package:evchargerapp/services/stations_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/station_sheet.dart';

void main() {
  final ChargingStationLocation station = ChargingStationLocation(
    id: 'st-01',
    name: 'Khan-Uul Fast Hub',
    latitude: 47.9000,
    longitude: 106.9000,
    address: 'Chinggis Avenue 12',
    distance: '1.2 км',
    kwSpeed: 120.0,
    availableConnectors: 1,
    totalConnectors: 1,
    pricePerKwh: 350.0,
    qrCode: 'KHAN01',
    isOnline: true,
    connectors: const <StationConnector>[
      StationConnector(
        connectorId: 1,
        status: 'Available',
        type: 'CCS2',
        powerKw: 120.0,
      ),
    ],
  );

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );

  testWidgets('directions button triggers onRoute callback when provided', (
    WidgetTester tester,
  ) async {
    bool routeCalled = false;

    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => showStationSheet(
              context,
              station: station,
              onRoute: () => routeCalled = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final directionsFinder = find.widgetWithText(
      OutlinedButton,
      AppStrings.get('directions'),
    );
    expect(directionsFinder, findsOneWidget);

    await tester.tap(directionsFinder);
    await tester.pumpAndSettle();

    expect(routeCalled, isTrue);
  });

  testWidgets('directions button requests targetStation on StationsService when onRoute is null', (
    WidgetTester tester,
  ) async {
    final StationsService stations = StationsService();
    stations.clearTargetStation();

    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => showStationSheet(
              context,
              station: station,
              stationsService: stations,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final directionsFinder = find.widgetWithText(
      OutlinedButton,
      AppStrings.get('directions'),
    );
    expect(directionsFinder, findsOneWidget);

    await tester.tap(directionsFinder);
    await tester.pumpAndSettle();

    expect(stations.targetStation.value?.id, 'st-01');
  });
}
