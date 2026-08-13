import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';

void main() {
  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
  });

  testWidgets('Mongolian Zev Charger App renders 70/30 Login screen and navigates on login', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const EvChargerApp());
    await tester.pump();

    // Verify Login Screen 70/30 slideshow & Zev Charger app name
    expect(find.text('Zev Charger'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Tap Login button to enter main app
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify ZEV CHARGER header & active tab
    expect(find.text('ZEV CHARGER'), findsOneWidget);
    expect(find.text('Нүүр'), findsOneWidget);
  });
}
