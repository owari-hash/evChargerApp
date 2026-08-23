import 'package:evchargerapp/models/auth_user.dart';
import 'package:evchargerapp/screens/account_screen.dart';
import 'package:evchargerapp/screens/sessions_screen.dart';
import 'package:evchargerapp/screens/wallet_screen.dart';
import 'package:evchargerapp/services/account_service.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/services/sessions_service.dart';
import 'package:evchargerapp/services/wallet_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// An auth service already holding the stubbed driver, as if just signed in.
AuthService _signedIn(ApiClient client) {
  final AuthService auth = AuthService(client: client);
  auth.currentUser.value = AuthUser.fromJson(kTestUser);
  return auth;
}

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  setUp(() => LanguageController.set(AppLanguage.mn));
  tearDown(() => LanguageController.set(AppLanguage.mn));

  testWidgets('account hub shows the driver and the way to each page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final ApiClient client = fakeApiClient(startSignedIn: true);
    await tester.pumpWidget(
      _host(
        AccountScreen(
          authService: _signedIn(client),
          accountService: AccountService(client: client),
        ),
      ),
    );
    await tester.pump();

    // The name shows in the header and again in the editable field; the
    // address in the header and again in the status card.
    expect(find.text('Бат Болд'), findsNWidgets(2));
    expect(find.text('bat@example.com'), findsNWidgets(2));

    // Every sub-page is reachable from here.
    expect(find.text(AppStrings.get('acct_nav_wallet')), findsOneWidget);
    expect(find.text(AppStrings.get('acct_nav_sessions')), findsOneWidget);
    expect(find.text(AppStrings.get('acct_nav_security')), findsOneWidget);

    // The linked charge tag is listed.
    expect(find.text('TAG-001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet shows the balance and its ledger', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final ApiClient client = fakeApiClient(startSignedIn: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: WalletScreen(walletService: WalletService(client: client)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('12,500₮'), findsOneWidget);

    // The ledger sits below the fold in a lazy list.
    await tester.scrollUntilVisible(
      find.text(AppStrings.get('wallet_history')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text(AppStrings.get('wallet_entry_topup')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('charging history lists a completed session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final ApiClient client = fakeApiClient(startSignedIn: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SessionsScreen(sessionsService: SessionsService(client: client)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Сүхбаатарын талбай'), findsOneWidget);
    expect(find.text('18.40 кВт·ц'), findsOneWidget);
    expect(find.text(AppStrings.get('sess_completed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
