import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';

import 'support/fake_auth.dart';

void main() {
  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
  });

  testWidgets(
    'sign-in screen renders and a valid credential lands on the dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(EvChargerApp(authService: fakeAuthService()));
      // Two pumps: one for the frame, one for the session check to settle.
      await tester.pump();
      await tester.pump();

      // The sign-in screen, with its wordmark and its single submit button.
      expect(find.text('E-Plug'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await signInThroughUi(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('E-PLUG'), findsOneWidget);
      expect(find.text('Нүүр'), findsOneWidget);
    },
  );

  testWidgets('a rejected credential keeps the driver on the sign-in screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(EvChargerApp(authService: fakeAuthService()));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), kTestIdentifier);
    await tester.enterText(find.byType(TextField).at(1), 'WrongPass1');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The API's message is shown, and the dashboard is not reached.
    expect(
      find.text('И-мэйл/утасны дугаар эсвэл нууц үг буруу байна'),
      findsOneWidget,
    );
    expect(find.text('E-PLUG'), findsNothing);
  });

  testWidgets('a saved session skips the sign-in screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      EvChargerApp(authService: fakeAuthService(startSignedIn: true)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('E-PLUG'), findsOneWidget);
  });
}
