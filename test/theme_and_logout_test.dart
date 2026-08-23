import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';

import 'support/fake_auth.dart';

/// The swipe control runs a looping hint animation, so the widget tree never
/// goes idle. Pump a fixed number of frames instead of settling.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 6]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Signs in against the stubbed driver API and lands on the dashboard.
Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(EvChargerApp(authService: fakeAuthService()));
  await tester.pump();
  // Let the saved-session check settle before the sign-in screen is expected.
  await tester.pump();

  await signInThroughUi(tester);
  await _pumpFrames(tester);
}

void main() {
  setUp(() {
    OcppMockService.enablePeriodicTimer = false;
    ThemeController.mode.value = ThemeMode.light;
  });

  tearDown(() => ThemeController.mode.value = ThemeMode.light);

  testWidgets('theme toggle sits before logout and flips the palette', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _login(tester);

    // Both actions are present, toggle first.
    final Finder toggle = find.byTooltip(AppStrings.get('dark'));
    final Finder logout = find.byTooltip(AppStrings.get('logout'));
    expect(toggle, findsOneWidget);
    expect(logout, findsOneWidget);
    expect(tester.getCenter(toggle).dx, lessThan(tester.getCenter(logout).dx));

    expect(ThemeController.isDark, isFalse);

    await tester.tap(toggle);
    await _pumpFrames(tester);

    expect(ThemeController.isDark, isTrue);
    expect(tester.takeException(), isNull);

    // The dark palette is actually in play.
    final BuildContext ctx = tester.element(find.byType(IndexedStack));
    expect(ctx.palette.bg, AppPalette.dark.bg);
  });

  testWidgets('logout asks first and cancelling keeps the session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _login(tester);
    expect(find.byType(IndexedStack), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.get('logout')));
    await _pumpFrames(tester);

    // Confirmation is shown rather than logging straight out.
    expect(find.text(AppStrings.get('logout_title')), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);

    await tester.tap(find.text(AppStrings.get('cancel')));
    await _pumpFrames(tester);

    expect(find.text(AppStrings.get('logout_title')), findsNothing);
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('confirming logout returns to the login screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _login(tester);
    await tester.tap(find.byTooltip(AppStrings.get('logout')));
    await _pumpFrames(tester);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.get('logout')),
    );
    await _pumpFrames(tester);

    expect(find.byType(IndexedStack), findsNothing);
  });

  testWidgets('dashboard survives a small screen in both themes', (
    WidgetTester tester,
  ) async {
    // 320pt-wide phone: the spec chips and quick actions used to overflow here.
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _login(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip(AppStrings.get('dark')));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
  });
}
