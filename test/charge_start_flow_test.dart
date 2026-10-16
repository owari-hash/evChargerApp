import 'dart:convert';

import 'package:evchargerapp/models/station.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/screens/trips_stations_screen.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:evchargerapp/services/sessions_service.dart';
import 'package:evchargerapp/services/stations_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/station_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'support/fake_auth.dart';

const ChargingStationLocation _station = ChargingStationLocation(
  id: 'cp1',
  name: 'Зайсан станц',
  address: 'Хан-Уул дүүрэг',
  distance: '2.1 км',
  kwSpeed: 120,
  availableConnectors: 1,
  totalConnectors: 2,
  pricePerKwh: 500,
  qrCode: 'cp1',
  latitude: 47.8864,
  longitude: 106.9058,
  connectors: <StationConnector>[
    StationConnector(connectorId: 1, status: 'Charging', type: 'GBT', powerKw: 60),
    StationConnector(connectorId: 2, status: 'Available', type: 'CCS2', powerKw: 120),
  ],
);

Map<String, dynamic> _stationJson() => <String, dynamic>{
  'id': 'cp1',
  'name': 'Зайсан станц',
  'address': 'Хан-Уул дүүрэг',
  'latitude': 47.8864,
  'longitude': 106.9058,
  'maxPowerKw': 120,
  'tariffPerKwh': 500,
  'totalConnectors': 2,
  'availableConnectors': 1,
  'isOnline': true,
  'connectors': <Map<String, dynamic>>[
    <String, dynamic>{'connectorId': 1, 'status': 'Charging', 'type': 'GBT', 'powerKw': 60},
    <String, dynamic>{'connectorId': 2, 'status': 'Available', 'type': 'CCS2', 'powerKw': 120},
  ],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

/// The stations half of the driver API. [startStatus] is what the charge
/// point answers RemoteStartTransaction with.
StationsService _stations({
  required List<http.Request> log,
  String startStatus = 'Accepted',
}) {
  return StationsService(
    client: ApiClient(
      sessionStore: InMemorySessionStore(),
      httpClient: MockClient((http.Request r) async {
        log.add(r);
        final String path = r.url.path;
        if (path.endsWith('/stations/cp1/start')) {
          return _json(<String, dynamic>{'status': startStatus});
        }
        if (path.endsWith('/stations/cp1/live')) {
          return _json(<String, dynamic>{'connectors': _stationJson()['connectors']});
        }
        if (path.endsWith('/stations/cp1')) {
          return _json(<String, dynamic>{'station': _stationJson()});
        }
        if (path.endsWith('/app/connector/GOOD1')) {
          return _json(<String, dynamic>{
            'stationId': 'cp1',
            'stationName': 'Зайсан станц',
            'connectorId': 2,
            'connectorType': 'CCS2',
          });
        }
        return _json(<String, dynamic>{'error': 'Энэ код олдсонгүй'}, 404);
      }),
    ),
  );
}

bool _isStart(http.Request r) =>
    r.method == 'POST' && r.url.path.endsWith('/start');

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A host page whose button opens [sheet], so the sheet has a route to pop.
Widget _host(void Function(BuildContext context) open) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: Builder(
      builder: (BuildContext context) => Center(
        child: TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

class _FakeScannerController extends MobileScannerController {
  _FakeScannerController() : super(autoStart: false);

  int starts = 0;
  int stops = 0;

  @override
  Future<void> start({CameraFacing? cameraDirection}) async => starts++;

  @override
  Future<void> stop() async => stops++;

  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

void main() {
  setUp(() {
    LanguageController.set(AppLanguage.mn);
  });

  Future<AuthService> signedIn() async {
    final AuthService auth = fakeAuthService(startSignedIn: true);
    await auth.restoreSession();
    expect(auth.isSignedIn, isTrue);
    return auth;
  }

  group('station sheet start', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required StationsService stations,
      required AuthService auth,
      SessionsService? sessions,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _host(
          (BuildContext context) => showStationSheet(
            context,
            station: _station,
            stationsService: stations,
            sessionsService: sessions ?? SessionsService(),
            authService: auth,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
    }

    testWidgets('shows the guns and starts on the free one when accepted', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      final SessionsService sessions = SessionsService();
      int ticks = 0;
      sessions.sessionStarted.addListener(() => ticks++);
      await openSheet(
        tester,
        stations: _stations(log: log),
        auth: await signedIn(),
        sessions: sessions,
      );

      expect(find.text('Зайсан станц'), findsOneWidget);
      expect(find.text('Хошуу 1'), findsOneWidget);
      expect(find.text('Хошуу 2'), findsOneWidget);
      expect(find.text('CCS2 · 120 кВт'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('charge-start-button')));
      await _settle(tester);

      final http.Request start = log.singleWhere(_isStart);
      expect(jsonDecode(start.body), <String, dynamic>{'connectorId': 2});
      expect(find.byType(StationSheet), findsNothing);
      expect(find.text(AppStrings.get('charge_started')), findsOneWidget);
      expect(ticks, 1);
    });

    testWidgets('a Rejected start stays on the sheet with the reason', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      final SessionsService sessions = SessionsService();
      int ticks = 0;
      sessions.sessionStarted.addListener(() => ticks++);
      await openSheet(
        tester,
        stations: _stations(log: log, startStatus: 'Rejected'),
        auth: await signedIn(),
        sessions: sessions,
      );

      await tester.tap(find.byKey(const ValueKey<String>('charge-start-button')));
      await _settle(tester);

      expect(log.where(_isStart), hasLength(1));
      expect(find.byType(StationSheet), findsOneWidget);
      expect(find.text(AppStrings.get('start_rejected')), findsOneWidget);
      expect(find.text(AppStrings.get('charge_started')), findsNothing);
      expect(ticks, 0);
      // Still there to try again.
      final ElevatedButton button = tester.widget(
        find.byKey(const ValueKey<String>('charge-start-button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a guest is asked to sign in before anything is sent', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      await openSheet(
        tester,
        stations: _stations(log: log),
        auth: fakeAuthService(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('charge-start-button')));
      await _settle(tester);

      expect(find.byType(LoginRegisterScreen), findsOneWidget);
      expect(log.where(_isStart), isEmpty);
    });
  });

  group('QR scanner', () {
    testWidgets('recovers after an unrecognised code', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);

      final List<http.Request> log = <http.Request>[];
      final _FakeScannerController controller = _FakeScannerController();
      String next = 'https://eplug.mn/c/BAD999';

      await tester.pumpWidget(
        _host(
          (BuildContext context) => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => QrScannerSheet(
              controller: controller,
              stationsService: _stations(log: log),
              authService: fakeAuthService(),
              scannerBuilder: (_, _, void Function(BarcodeCapture) onDetect) =>
                  GestureDetector(
                    key: const ValueKey<String>('fake-camera'),
                    onTap: () => onDetect(
                      BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: next)]),
                    ),
                    child: const ColoredBox(color: Colors.black),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('fake-camera')));
      await _settle(tester);

      // Back on the camera, with the reason, and the camera restarted.
      expect(find.byKey(const ValueKey<String>('scan-error')), findsOneWidget);
      expect(controller.stops, 1);
      expect(controller.starts, 1);

      // The next sticker is read — it used to be ignored for good.
      next = 'https://eplug.mn/c/GOOD1';
      await tester.tap(find.byKey(const ValueKey<String>('fake-camera')));
      await _settle(tester);

      expect(find.text(AppStrings.get('pick_connector')), findsOneWidget);
      expect(find.text('Хошуу 2'), findsOneWidget);
    });
  });
}
