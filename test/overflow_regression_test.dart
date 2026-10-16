import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/screens/quick_controls_screen.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/models/station.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:evchargerapp/services/stations_service.dart';
import 'package:evchargerapp/widgets/station_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Screen widths worth caring about: iPhone SE through Pro Max.
const List<Size> _phones = <Size>[
  Size(320, 568),
  Size(390, 844),
  Size(430, 932),
];

Future<void> _pumpFrames(WidgetTester tester, [int frames = 4]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const ChargingStationLocation _sampleStation = ChargingStationLocation(
  id: 'cp1',
  name: 'Сүхбаатарын талбайн цэнэглэх станц',
  address: 'Улаанбаатар, Сүхбаатар дүүрэг, 1-р хороо, Энхтайваны өргөн чөлөө',
  distance: '1.2 км',
  kwSpeed: 120,
  availableConnectors: 1,
  totalConnectors: 3,
  pricePerKwh: 1234.56,
  feePercent: 5,
  qrCode: 'cp1',
  latitude: 47.9188,
  longitude: 106.9176,
  connectors: <StationConnector>[
    StationConnector(connectorId: 1, status: 'Available', type: 'CCS2', powerKw: 120),
    StationConnector(connectorId: 2, status: 'Charging', type: 'GBT', powerKw: 60),
    StationConnector(connectorId: 3, status: 'Faulted', type: 'Type2', powerKw: 22),
  ],
);

ApiClient _offlineClient() => ApiClient(
  sessionStore: InMemorySessionStore(),
  httpClient: MockClient((http.Request r) async => http.Response('{}', 404)),
);

void main() {
  for (final ThemeData theme in <ThemeData>[
    AppTheme.lightTheme,
    AppTheme.darkTheme,
  ]) {
    final String mode = theme.brightness == Brightness.dark ? 'dark' : 'light';

    for (final Size size in _phones) {
      testWidgets('station sheet fits ${size.width.toInt()}pt ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: StationSheet(
                  station: _sampleStation,
                  onRoute: _noop,
                  stationsService: StationsService(client: _offlineClient()),
                ),
              ),
            ),
          ),
        );
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Хошуу 1'), findsOneWidget);
      });

      testWidgets('quick controls fits ${size.width.toInt()}pt ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(theme: theme, home: const QuickControlsScreen()),
        );
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('login fits ${size.width.toInt()}pt with no scroll ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: LoginRegisterScreen(onLoginSuccess: _noop),
          ),
        );
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);

        // The submit button must be fully on screen without scrolling: the
        // sheet used to be a fixed 30% with its own scroll view, which left
        // dead space on tall phones and hid the button on short ones.
        final Finder submit = find.byType(ElevatedButton);
        expect(submit, findsOneWidget);
        final Rect box = tester.getRect(submit);
        expect(box.bottom, lessThanOrEqualTo(size.height + 0.5));
        expect(box.top, greaterThanOrEqualTo(0));

        // Signing in must fit outright, so every field is visible without the
        // driver scrolling for it.
        for (final Rect field
            in tester
                .widgetList<TextField>(find.byType(TextField))
                .map((TextField f) => tester.getRect(find.byWidget(f)))) {
          expect(field.top, greaterThanOrEqualTo(0));
          expect(field.bottom, lessThanOrEqualTo(size.height + 0.5));
        }
      });

      testWidgets('sign-up fits ${size.width.toInt()}pt ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: LoginRegisterScreen(onLoginSuccess: _noop),
          ),
        );
        await _pumpFrames(tester);

        // Step one of sign-up: the phone number and the terms line.
        await tester.tap(find.text(AppStrings.get('register')));
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(Checkbox), findsOneWidget);

        // The button stays pinned below the scrolling fields.
        final Finder submit = find.byType(ElevatedButton);
        expect(submit, findsOneWidget);
        final Rect box = tester.getRect(submit);
        expect(box.bottom, lessThanOrEqualTo(size.height + 0.5));
        expect(box.top, greaterThanOrEqualTo(0));
      });
    }
  }
}

void _noop() {}

