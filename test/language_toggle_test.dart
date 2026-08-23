import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/screens/mongolia_map_screen.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';

import 'support/fake_auth.dart';

Future<void> _pumpFrames(WidgetTester tester, [int frames = 6]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

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
    LanguageController.set(AppLanguage.mn);
    ThemeController.mode.value = ThemeMode.light;
  });

  tearDown(() => LanguageController.set(AppLanguage.mn));

  test('language notifier drives AppStrings', () {
    expect(AppStrings.get('home'), 'Нүүр');
    LanguageController.set(AppLanguage.en);
    expect(AppStrings.get('home'), 'Home');
    LanguageController.toggle();
    expect(AppStrings.currentLanguage, AppLanguage.mn);
  });

  test('map guidance follows the language', () {
    // Regression: guidance was hardcoded Mongolian and ignored the toggle.
    LanguageController.set(AppLanguage.mn);
    expect(compassLabel(90), 'зүүн');
    expect(navigationInstruction(4200, 90), contains('км'));

    LanguageController.set(AppLanguage.en);
    expect(compassLabel(90), 'east');
    expect(navigationInstruction(4200, 90), contains('km'));
    expect(navigationInstruction(10, 90), 'You have arrived');
  });

  testWidgets('MN/EN toggle sits in the app bar and retitles the menus', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _login(tester);

    // Menu label starts in Mongolian.
    expect(find.text('Нүүр'), findsOneWidget);

    // The switcher shows flags rather than language codes.
    await tester.tap(find.text(AppLanguage.en.flag));
    await _pumpFrames(tester);

    // The whole app rebuilt, not just the screen that owns the switch.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Нүүр'), findsNothing);

    await tester.tap(find.text(AppLanguage.mn.flag));
    await _pumpFrames(tester);
    expect(find.text('Нүүр'), findsOneWidget);
  });
}
