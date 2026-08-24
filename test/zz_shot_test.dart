import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'support/fake_auth.dart';

void main() {
  testWidgets('shot: sign-up terms line', (WidgetTester tester) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginRegisterScreen(authService: fakeAuthService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Бүртгүүлэх').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginRegisterScreen),
      matchesGoldenFile('zz_signup.png'),
    );
  });
}
