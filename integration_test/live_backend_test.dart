import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end against a **running** stack, not a stub:
///
///   this app -> evChargerKiosk (:3100) -> evChargerBack (:3000) -> MongoDB
///
/// Start both servers, seed a driver, then:
///
/// ```sh
/// flutter test integration_test/live_backend_test.dart \
///   -d <simulator-id> --dart-define=API_BASE_URL=http://127.0.0.1:3100
/// ```
///
/// The define is required: without it the app targets production, where this
/// seeded driver and its balance do not exist.
///
/// The driver below is the one created by the local dev seed.
const String kIdentifier = '99118844';
const String kPassword = 'Charge123';

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in against the live driver API and reads the wallet',
      (WidgetTester tester) async {
    // Start from a clean session so the sign-in screen is what comes up.
    await ApiClient.shared.clearSession();
    AuthService.instance.currentUser.value = null;
    LanguageController.set(AppLanguage.mn);

    await tester.pumpWidget(const EvChargerApp());
    await _settle(tester);

    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), kIdentifier);
    await tester.enterText(find.byType(TextField).at(1), kPassword);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await _settle(tester, 24);

    // The real API answered and the app moved on to the dashboard.
    expect(find.text('E-PLUG'), findsOneWidget);
    expect(AuthService.instance.currentUser.value?.email, 'bat@example.com');

    // Account tab, then the wallet. The nav shows a label only on the selected
    // item, so the tab is reached by its icon.
    await tester.tap(find.byIcon(Icons.person_rounded));
    await _settle(tester);
    expect(find.text('Бат Болд'), findsWidgets);

    await tester.tap(find.text(AppStrings.get('acct_nav_wallet')));
    await _settle(tester, 24);

    // The balance the CSMS really holds for this driver.
    expect(find.text('15,800₮'), findsOneWidget);
  });
}
