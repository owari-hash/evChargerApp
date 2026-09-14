import 'dart:convert';

import 'package:evchargerapp/models/auth_user.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:evchargerapp/services/biometric_service.dart';

import 'support/fake_auth.dart';
import 'support/fake_biometrics.dart';

Map<String, dynamic> _body(http.Request request) => request.body.isEmpty
    ? <String, dynamic>{}
    : jsonDecode(request.body) as Map<String, dynamic>;

List<String> _paths(List<http.Request> log) =>
    log.map((http.Request r) => r.url.path).toList();

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(
  WidgetTester tester,
  AuthService auth,
  VoidCallback onLoginSuccess, {
  BiometricService? biometrics,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: LoginRegisterScreen(
        authService: auth,
        biometricService: biometrics ?? fakeBiometrics(kind: null),
        onLoginSuccess: onLoginSuccess,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Drops focus first: a text selection handle left over from `enterText` can
/// sit on the pinned button and swallow the tap.
Future<void> _submit(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.tap(find.byType(ElevatedButton));
  await _settle(tester);
}

Finder get _fields => find.byType(TextField);

void main() {
  setUp(() => AppStrings.currentLanguage = AppLanguage.mn);

  group('AuthService', () {
    test('signs in with the phone number and PIN, and nothing else', () async {
      final List<http.Request> log = <http.Request>[];
      final AuthService auth = fakeAuthService(log: log);

      final AuthUser user = await auth.signIn(phone: kTestPhone, pin: kTestPin);

      expect(user.phone, '+97699118844');
      expect(_body(log.single), <String, dynamic>{
        'phone': kTestPhone,
        'pin': kTestPin,
      });
    });

    test('a wrong PIN is a 401 with the API message', () async {
      final AuthService auth = fakeAuthService();

      await expectLater(
        auth.signIn(phone: kTestPhone, pin: '0000'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 401)
              .having(
                (ApiException e) => e.message,
                'message',
                contains('PIN код буруу'),
              ),
        ),
      );
      expect(auth.currentUser.value, isNull);
    });

    test('sign-up trades the code for a ticket, then the ticket and PIN for '
        'an account', () async {
      final List<http.Request> log = <http.Request>[];
      final AuthService auth = fakeAuthService(log: log);

      final CodeSent sent = await auth.sendSignupCode(kTestPhone);
      final String ticket = await auth.verifySignupCode(
        phone: kTestPhone,
        code: kTestCode,
      );
      final AuthUser user = await auth.completeSignup(
        ticket: ticket,
        pin: '1234',
        confirmPin: '1234',
      );

      expect(sent.destination, endsWith('8844'));
      expect(auth.currentUser.value, same(user));
      expect(_paths(log), <String>[
        '/app-api/auth/signup/send-code',
        '/app-api/auth/signup/verify',
        '/app-api/auth/signup/complete',
      ]);
      expect(_body(log[0])['acceptTerms'], isTrue);
      expect(_body(log[2]), <String, dynamic>{
        'signupTicket': 'stub-ticket',
        'pin': '1234',
        'confirmPin': '1234',
      });
    });

    test('a PIN reset uses its own endpoints and ticket', () async {
      final List<http.Request> log = <http.Request>[];
      final AuthService auth = fakeAuthService(log: log);

      await auth.sendPinResetCode(kTestPhone);
      final String ticket = await auth.verifyPinResetCode(
        phone: kTestPhone,
        code: kTestCode,
      );
      await auth.resetPin(ticket: ticket, pin: '5678', confirmPin: '5678');

      expect(_paths(log), <String>[
        '/app-api/auth/pin/forgot',
        '/app-api/auth/pin/verify',
        '/app-api/auth/pin/reset',
      ]);
      expect(_body(log[2])['resetTicket'], 'stub-ticket');
      expect(auth.isSignedIn, isTrue);
    });
  });

  group('Face ID / fingerprint', () {
    testWidgets('after a PIN sign-in the app offers Face ID, and turning it '
        'on remembers the credentials', (WidgetTester tester) async {
      final BiometricService biometrics = fakeBiometrics();
      bool signedIn = false;
      await _open(
        tester,
        fakeAuthService(),
        () => signedIn = true,
        biometrics: biometrics,
      );

      await tester.enterText(_fields.at(0), kTestPhone);
      await tester.enterText(_fields.at(1), kTestPin);
      await _submit(tester);
      await _settle(tester);

      expect(
        find.text(AppStrings.get('bio_offer_title_face')),
        findsOneWidget,
      );
      await tester.tap(find.text(AppStrings.get('bio_enable')));
      await _settle(tester);

      expect(signedIn, isTrue);
      expect(await biometrics.isEnabled(), isTrue);
    });

    testWidgets('"Not now" signs in and does not ask again', (
      WidgetTester tester,
    ) async {
      final BiometricService biometrics = fakeBiometrics();
      bool signedIn = false;
      await _open(
        tester,
        fakeAuthService(),
        () => signedIn = true,
        biometrics: biometrics,
      );

      await tester.enterText(_fields.at(0), kTestPhone);
      await tester.enterText(_fields.at(1), kTestPin);
      await _submit(tester);
      await _settle(tester);
      await tester.tap(find.text(AppStrings.get('bio_not_now')));
      await _settle(tester);

      expect(signedIn, isTrue);
      expect(await biometrics.isEnabled(), isFalse);
      expect(await biometrics.wasDeclined(), isTrue);
    });

    testWidgets('with Face ID on, one tap signs in without typing the PIN', (
      WidgetTester tester,
    ) async {
      final BiometricService biometrics = fakeBiometrics();
      await biometrics.enable(phone: kTestPhone, pin: kTestPin, reason: '');
      final List<http.Request> log = <http.Request>[];
      bool signedIn = false;
      await _open(
        tester,
        fakeAuthService(log: log),
        () => signedIn = true,
        biometrics: biometrics,
      );
      await _settle(tester);

      await tester.tap(
        find.byTooltip(AppStrings.get('bio_sign_in_face')),
      );
      await _settle(tester);

      expect(signedIn, isTrue);
      expect(_body(log.single), <String, dynamic>{
        'phone': kTestPhone,
        'pin': kTestPin,
      });
    });

    testWidgets('a remembered PIN that no longer works is forgotten', (
      WidgetTester tester,
    ) async {
      final BiometricService biometrics = fakeBiometrics();
      await biometrics.enable(phone: kTestPhone, pin: '9999', reason: '');
      bool signedIn = false;
      await _open(
        tester,
        fakeAuthService(),
        () => signedIn = true,
        biometrics: biometrics,
      );
      await _settle(tester);

      await tester.tap(
        find.byTooltip(AppStrings.get('bio_sign_in_face')),
      );
      await _settle(tester);

      expect(signedIn, isFalse);
      expect(find.text(AppStrings.get('bio_stale')), findsOneWidget);
      expect(await biometrics.isEnabled(), isFalse);
      expect(
        find.byTooltip(AppStrings.get('bio_sign_in_face')),
        findsNothing,
      );
    });

    testWidgets('a device without biometrics shows no button and no offer', (
      WidgetTester tester,
    ) async {
      bool signedIn = false;
      await _open(tester, fakeAuthService(), () => signedIn = true);

      expect(find.byTooltip(AppStrings.get('bio_sign_in_face')), findsNothing);
      await tester.enterText(_fields.at(0), kTestPhone);
      await tester.enterText(_fields.at(1), kTestPin);
      await _submit(tester);

      expect(signedIn, isTrue);
      expect(find.text(AppStrings.get('bio_offer_title_face')), findsNothing);
    });
  });

  group('LoginRegisterScreen', () {
    testWidgets('signing in takes the phone number and a 4-digit PIN', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      bool signedIn = false;
      await _open(tester, fakeAuthService(log: log), () => signedIn = true);

      expect(_fields, findsNWidgets(2));
      await tester.enterText(_fields.at(0), kTestPhone);
      await tester.enterText(_fields.at(1), kTestPin);
      await _submit(tester);

      expect(signedIn, isTrue);
      expect(_paths(log), <String>['/app-api/auth/login']);
    });

    testWidgets('a short PIN is caught before anything is sent', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      await _open(tester, fakeAuthService(log: log), () {});

      await tester.enterText(_fields.at(0), kTestPhone);
      await tester.enterText(_fields.at(1), '12');
      await _submit(tester);

      expect(find.text(AppStrings.get('auth_bad_pin')), findsOneWidget);
      expect(log, isEmpty);
    });

    testWidgets('sign-up: phone and terms, then the code, then the PIN twice', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      bool signedIn = false;
      await _open(tester, fakeAuthService(log: log), () => signedIn = true);

      await tester.tap(find.text(AppStrings.get('register')));
      await _settle(tester);

      // Step 1 is the number alone; without the terms nothing is sent.
      expect(_fields, findsOneWidget);
      await tester.enterText(_fields.first, kTestPhone);
      await _submit(tester);
      expect(find.text(AppStrings.get('auth_terms_required')), findsOneWidget);
      expect(log, isEmpty);

      await tester.tap(find.byType(Checkbox));
      await _submit(tester);
      expect(find.text(AppStrings.get('auth_code_headline')), findsOneWidget);

      // A wrong code keeps the driver on this step with the API's words.
      await tester.enterText(_fields.first, '000000');
      await _settle(tester);
      expect(find.text('Энэ код буруу байна'), findsOneWidget);
      expect(find.text(AppStrings.get('auth_code_headline')), findsOneWidget);

      // The sixth digit of the right code sends it by itself.
      await tester.enterText(_fields.first, kTestCode);
      await _settle(tester);
      expect(find.text(AppStrings.get('auth_pin_headline')), findsOneWidget);

      // A repeat that does not match is caught as soon as it is complete.
      await tester.enterText(_fields.at(0), '1234');
      await tester.enterText(_fields.at(1), '4321');
      await _settle(tester);
      expect(find.text(AppStrings.get('auth_pin_mismatch')), findsOneWidget);
      expect(signedIn, isFalse);

      await tester.enterText(_fields.at(1), '1234');
      await _submit(tester);

      expect(signedIn, isTrue);
      expect(_paths(log), <String>[
        '/app-api/auth/signup/send-code',
        '/app-api/auth/signup/verify',
        '/app-api/auth/signup/verify',
        '/app-api/auth/signup/complete',
      ]);
      expect(_body(log.last), <String, dynamic>{
        'signupTicket': 'stub-ticket',
        'pin': '1234',
        'confirmPin': '1234',
      });
    });

    testWidgets('a forgotten PIN is reset through the same three steps', (
      WidgetTester tester,
    ) async {
      final List<http.Request> log = <http.Request>[];
      bool signedIn = false;
      await _open(tester, fakeAuthService(log: log), () => signedIn = true);

      // The number typed on the sign-in form carries over.
      await tester.enterText(_fields.at(0), kTestPhone);
      await tester.tap(find.text(AppStrings.get('forgot_pin')));
      await _settle(tester);
      expect(find.text(AppStrings.get('auth_reset_headline')), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      await _submit(tester);
      await tester.enterText(_fields.first, kTestCode);
      await _settle(tester);
      expect(
        find.text(AppStrings.get('auth_reset_pin_headline')),
        findsOneWidget,
      );

      await tester.enterText(_fields.at(0), '5678');
      await tester.enterText(_fields.at(1), '5678');
      await _submit(tester);

      expect(signedIn, isTrue);
      expect(_paths(log), <String>[
        '/app-api/auth/pin/forgot',
        '/app-api/auth/pin/verify',
        '/app-api/auth/pin/reset',
      ]);
      expect(_body(log.first)['phone'], kTestPhone);
    });
  });
}
