import 'dart:io';
import 'dart:ui' as ui;

import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/models/station.dart';
import 'package:evchargerapp/services/announcement_watcher_service.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/notifications_store.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:evchargerapp/services/stations_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/station_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth.dart';

const String _out =
    '/private/tmp/claude-501/-Users-macbookairm4-evChargerApp/1567d0f9-29e8-4847-bd87-77922e9a592a/scratchpad/tidy';

Future<void> _fonts() async {
  final FontLoader geist = FontLoader('Geist');
  for (final String w in <String>['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    geist.addFont(rootBundle.load('assets/fonts/Geist-$w.ttf'));
  }
  await geist.load();
  final FontLoader icons = FontLoader('MaterialIcons');
  icons.addFont(Future<ByteData>.value(ByteData.sublistView(File(
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync())));
  await icons.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final RenderRepaintBoundary b = tester.renderObject(find.byKey(const ValueKey<String>('shot')));
  await tester.runAsync(() async {
    final ui.Image im = await b.toImage(pixelRatio: 2.0);
    final ByteData? png = await im.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _frames(WidgetTester tester, [int n = 15]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    AppStrings.currentLanguage = AppLanguage.mn;
  });

  testWidgets('home idle', (WidgetTester tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey<String>('shot'),
      child: EvChargerApp(authService: fakeAuthService(startSignedIn: true), startupPrompts: (_) async {}),
    ));
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey<String>('nav-tab-0')));
    await _frames(tester);
    await _shot(tester, 'app-home-idle');
  });

  testWidgets('station sheet', (WidgetTester tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    const ChargingStationLocation station = ChargingStationLocation(
      id: 'cp1',
      name: 'Зайсан Хилл цэнэглэх станц',
      address: 'Улаанбаатар, Хан-Уул дүүрэг, 11-р хороо',
      distance: '2.4 км',
      kwSpeed: 120,
      availableConnectors: 1,
      totalConnectors: 3,
      pricePerKwh: 525,
      feePercent: 5,
      qrCode: 'cp1',
      latitude: 47.8864,
      longitude: 106.9058,
      connectors: <StationConnector>[
        StationConnector(connectorId: 1, status: 'Available', type: 'CCS2', powerKw: 120),
        StationConnector(connectorId: 2, status: 'Charging', type: 'GBT', powerKw: 60),
        StationConnector(connectorId: 3, status: 'Faulted', type: 'Type2', powerKw: 22),
      ],
    );
    final StationsService offline = StationsService(
      client: ApiClient(
        sessionStore: InMemorySessionStore(),
        httpClient: MockClient((http.Request r) async => http.Response('{}', 404)),
      ),
    );
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey<String>('shot'),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFFB9C9BF),
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => showStationSheet(context, station: station, onRoute: () {}, stationsService: offline),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await _frames(tester);
    await _shot(tester, 'app-map-station-sheet');
  });

  testWidgets('announcement in the bell', (WidgetTester tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    // No feed: the entry is filed directly, as the watcher would.
    AnnouncementWatcherService.instance.signOut();
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey<String>('shot'),
      child: EvChargerApp(authService: fakeAuthService(startSignedIn: true), startupPrompts: (_) async {}),
    ));
    await _frames(tester);
    {
      await NotificationsStore.instance.add(
        kind: NotificationKind.wallet,
        title: 'Цэнэглэлт',
        body: '+20,000₮',
      );
      await NotificationsStore.instance.add(
        kind: NotificationKind.announcement,
        title: 'Шинэ станц нээгдлээ',
        body: 'Зайсанд 120 кВт-ын хурдан цэнэглэгч ажиллаж эхэллээ. Нээлтийн долоо хоногт үйлчилгээний хураамжгүй.',
      );
    }
    await _frames(tester, 5);
    await tester.tap(find.byIcon(Icons.notifications_rounded).first);
    await _frames(tester, 10);
    await _shot(tester, 'app-bell-announcement');
    await tester.tap(find.text('Шинэ станц нээгдлээ'));
    await _frames(tester, 10);
    await _shot(tester, 'app-announcement-dialog');
  });

  testWidgets('map tab', (WidgetTester tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    StationsService.instance.stations.value = <ChargingStationLocation>[
      ChargingStationLocation.fromJson(<String, dynamic>{
        'id': 'cp1', 'name': 'Зайсан', 'latitude': 47.8864, 'longitude': 106.9058,
        'availableConnectors': 1, 'totalConnectors': 2, 'isOnline': true,
      })!,
    ];
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey<String>('shot'),
      child: EvChargerApp(authService: fakeAuthService(startSignedIn: true), startupPrompts: (_) async {}),
    ));
    await _frames(tester);
    await _shot(tester, 'app-map-tab');
  });
}
