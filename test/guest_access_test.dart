import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/screens/mongolia_map_screen.dart';
import 'package:evchargerapp/screens/trips_stations_screen.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/signed_out_panel.dart';

import 'support/fake_auth.dart';

/// App Store guideline 5.1.1(v): the app may not require an account to reach
/// features that are not account based. Finding a charger is not account
/// based; charging a car and paying for it is.
///
/// Version 1.0.1 was rejected because every tab sat behind a sign-in wall.
/// These tests are what stop that wall coming back.
Future<void> _launchAsGuest(WidgetTester tester) async {
  await tester.pumpWidget(EvChargerApp(authService: fakeAuthService()));
  await tester.pump();
  await tester.pump();
}

Future<void> _openTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey<String>('nav-tab-$index')));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
    AppStrings.currentLanguage = AppLanguage.mn;
  });

  testWidgets('a guest reaches the app without signing in', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _launchAsGuest(tester);

    // No wall: the tab bar is up and the map is showing.
    expect(find.byType(MongoliaMapScreen), findsOneWidget);
    expect(find.byType(LoginRegisterScreen).hitTestable(), findsNothing);

    // And the way in is offered rather than imposed.
    expect(find.byTooltip(AppStrings.get('login')), findsOneWidget);
  });

  testWidgets('a guest can browse the station list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _launchAsGuest(tester);
    await _openTab(tester, 3);

    // The stations tab renders for a guest — no sign-in panel in the way.
    expect(find.byType(TripsStationsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TripsStationsScreen),
        matching: find.byType(SignedOutPanel),
      ),
      findsNothing,
    );
    expect(find.text(AppStrings.get('nearby_stations')), findsOneWidget);
  });

  testWidgets('account-based tabs offer sign-in instead of a wall', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _launchAsGuest(tester);

    // The vehicle dashboard is the driver's own, so it asks for an account.
    await _openTab(tester, 0);
    expect(find.byType(SignedOutPanel), findsOneWidget);
    expect(find.text(AppStrings.get('guest_vehicle_title')), findsOneWidget);

    // Charging controls likewise.
    await _openTab(tester, 2);
    expect(find.byType(SignedOutPanel), findsOneWidget);
    expect(find.text(AppStrings.get('guest_controls_title')), findsOneWidget);

    // Both are still reachable — nothing has blocked the rest of the app.
    await _openTab(tester, 1);
    expect(find.byType(MongoliaMapScreen), findsOneWidget);
  });

  testWidgets('signing in from the account tab returns to the map', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _launchAsGuest(tester);
    await signInThroughUi(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(AppStrings.get('map')), findsOneWidget);
    // The app bar swaps the way in for the way out.
    expect(find.byTooltip(AppStrings.get('logout')), findsOneWidget);
    expect(find.byTooltip(AppStrings.get('login')), findsNothing);
  });
}
