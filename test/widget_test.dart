import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';

import 'support/fake_auth.dart';

void main() {
  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
  });

  testWidgets('a guest lands on the map, and signing in keeps them there', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(EvChargerApp(authService: fakeAuthService()));
    // Two pumps: one for the frame, one for the session check to settle.
    await tester.pump();
    await tester.pump();

    // No wall: the guest is inside the app with the tab bar under them.
    expect(find.text('Eplug'), findsOneWidget);
    expect(find.byType(LoginRegisterScreen).hitTestable(), findsNothing);

    // The map is the landing tab, so its label is the one showing.
    expect(find.text(AppStrings.get('map')), findsOneWidget);

    await signInThroughUi(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // Signing in on the account tab returns the driver to the map.
    expect(find.text('Eplug'), findsOneWidget);
    expect(find.text(AppStrings.get('map')), findsOneWidget);
  });

  testWidgets('a rejected credential keeps the driver on the sign-in form', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(EvChargerApp(authService: fakeAuthService()));
    await tester.pump();
    await tester.pump();

    // The sign-in form lives on the account tab now.
    await tester.tap(find.byKey(const ValueKey<String>('nav-tab-4')));
    await tester.pump();
    await tester.pump();

    final Finder form = find.byType(LoginRegisterScreen);
    final Finder fields = find.descendant(
      of: form,
      matching: find.byType(TextField),
    );

    await tester.enterText(fields.at(0), kTestIdentifier);
    await tester.enterText(fields.at(1), 'WrongPass1');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.tap(
      find.descendant(of: form, matching: find.byType(ElevatedButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The API's message is shown, and the dashboard is not reached.
    expect(
      find.text('И-мэйл/утасны дугаар эсвэл нууц үг буруу байна'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.get('map')), findsNothing);
  });

  testWidgets('a saved session opens straight on the map', (
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

    expect(find.text('Eplug'), findsOneWidget);
    expect(find.text(AppStrings.get('map')), findsOneWidget);
  });
}
