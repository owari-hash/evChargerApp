import 'dart:convert';

import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The driver the stubbed API signs in.
const Map<String, dynamic> kTestUser = <String, dynamic>{
  'id': 'usr_test',
  'email': 'bat@example.com',
  'phone': '+97699118844',
  'name': 'Бат Болд',
  'emailVerified': true,
  'phoneVerified': true,
  'hasPin': true,
  'idTags': <String>['TAG-001'],
  'locale': 'mn',
};

/// Credentials that the stub accepts. Anything else comes back 401.
const String kTestPhone = '99118844';
const String kTestPin = '1234';

/// The SMS code the stub "texts" for sign-up and PIN resets.
const String kTestCode = '123456';

/// An [AuthService] wired to an in-memory driver API, so widget tests can sign
/// in and out without a server or the platform keychain.
///
/// Pass [startSignedIn] to begin with a stored session, the way a returning
/// driver launches the app, and [log] to record every request the app sends.
ApiClient fakeApiClient({
  bool startSignedIn = false,
  List<http.Request>? log,
}) {
  final SessionStore store = InMemorySessionStore();
  if (startSignedIn) store.write('evapp_session=stub');
  return ApiClient(sessionStore: store, httpClient: _stubClient(log));
}

AuthService fakeAuthService({
  bool startSignedIn = false,
  List<http.Request>? log,
}) => AuthService(
  client: fakeApiClient(startSignedIn: startSignedIn, log: log),
);

MockClient _stubClient(List<http.Request>? log) {
  return MockClient((http.Request request) async {
    log?.add(request);
    final String path = request.url.path;
    final Map<String, dynamic> body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;

    http.Response ok(Object payload) => http.Response(
      jsonEncode(payload),
      200,
      headers: <String, String>{
        'content-type': 'application/json',
        'set-cookie': 'evapp_session=stub-token; Path=/; HttpOnly',
      },
    );

    http.Response fail(
      int status,
      String message, [
      Map<String, String> fields = const <String, String>{},
    ]) => http.Response(
      jsonEncode(<String, dynamic>{'error': message, 'fields': fields}),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

    if (path.endsWith('/auth/login')) {
      final bool matches =
          body['phone'] == kTestPhone && body['pin'] == kTestPin;
      return matches
          ? ok(<String, dynamic>{'user': kTestUser})
          : fail(401, 'Утасны дугаар эсвэл PIN код буруу байна');
    }

    if (path.endsWith('/auth/signup/send-code') ||
        path.endsWith('/auth/pin/forgot')) {
      return ok(<String, dynamic>{'ok': true, 'destination': '********8844'});
    }

    if (path.endsWith('/auth/signup/verify') ||
        path.endsWith('/auth/pin/verify')) {
      if (body['code'] != kTestCode) {
        return fail(
          400,
          'Энэ код буруу эсвэл хугацаа нь дууссан байна. Шинэ код авна уу.',
          <String, String>{'code': 'Энэ код буруу байна'},
        );
      }
      final String key = path.endsWith('/auth/signup/verify')
          ? 'signupTicket'
          : 'resetTicket';
      return ok(<String, dynamic>{'ok': true, key: 'stub-ticket'});
    }

    if (path.endsWith('/auth/signup/complete') ||
        path.endsWith('/auth/pin/reset')) {
      return ok(<String, dynamic>{'user': kTestUser});
    }

    if (path.endsWith('/auth/me')) {
      return ok(<String, dynamic>{'user': kTestUser});
    }

    if (path.endsWith('/auth/logout')) {
      return http.Response(
        jsonEncode(<String, bool>{'ok': true}),
        200,
        headers: <String, String>{
          'content-type': 'application/json',
          'set-cookie': 'evapp_session=; Path=/; Max-Age=0',
        },
      );
    }

    if (path.endsWith('/wallet')) {
      return ok(<String, dynamic>{
        'wallet': <String, dynamic>{
          'id': 'w_1',
          'balance': 12500,
          'currency': 'MNT',
          'status': 'ACTIVE',
          'totalToppedUp': 50000,
          'totalSpent': 37500,
          'idTags': <String>['TAG-001'],
        },
        'config': <String, dynamic>{
          'enabled': true,
          'topUpEnabled': true,
          'presets': <int>[5000, 10000, 20000],
          'minTopUp': 100,
          'maxTopUp': 5000000,
          'minStartBalance': 1000,
        },
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'e_1',
            'type': 'TOPUP',
            'amount': 20000,
            'balanceAfter': 12500,
            'currency': 'MNT',
            'createdAt': '2026-08-20T09:00:00.000Z',
          },
        ],
        'total': 1,
      });
    }

    if (path.endsWith('/sessions')) {
      return ok(<String, dynamic>{
        'sessions': <Map<String, dynamic>>[
          <String, dynamic>{
            'transactionId': 42,
            'chargePointId': 'CP-DEMO-001',
            'stationName': 'Сүхбаатарын талбай',
            'connectorId': 1,
            'idTag': 'TAG-001',
            'status': 'Completed',
            'startTimestamp': '2026-08-20T09:00:00.000Z',
            'stopTimestamp': '2026-08-20T09:42:00.000Z',
            'energyKwh': 18.4,
            'cost': 9200,
          },
        ],
      });
    }

    if (path.endsWith('/account/profile')) {
      return ok(<String, dynamic>{
        'user': <String, dynamic>{...kTestUser, 'name': 'Шинэ Нэр'},
      });
    }

    if (path.endsWith('/account/pin')) {
      return ok(<String, dynamic>{'ok': true, 'user': kTestUser});
    }

    return fail(404, 'Хүсэлт олдсонгүй');
  });
}

/// Signs a driver in through the UI, from wherever the app currently is.
///
/// There is no sign-in wall any more — a guest lands in the tab frame — so
/// this opens the account tab first when the form is not already on screen.
/// Every finder is scoped to the sign-in screen because the tab frame keeps
/// all five tabs alive in an [IndexedStack], and the map and station tabs have
/// text fields and buttons of their own.
///
/// Focus is dropped before the tap on purpose: `enterText` leaves a text
/// selection handle in the overlay, which on a tall phone lands on top of the
/// pinned submit button and swallows the tap.
Future<void> signInThroughUi(WidgetTester tester) async {
  final Finder form = find.byType(LoginRegisterScreen);

  // The tab frame keeps every tab built, so the sign-in screen exists in the
  // widget tree even while another tab is showing. Ask whether it is actually
  // on screen, not merely whether it was built.
  if (form.hitTestable().evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey<String>('nav-tab-4')));
    await tester.pump();
    await tester.pump();
  }

  final Finder fields = find.descendant(
    of: form,
    matching: find.byType(TextField),
  );

  // The phone number, then the PIN boxes' hidden input.
  await tester.enterText(fields.at(0), kTestPhone);
  await tester.enterText(fields.at(1), kTestPin);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();

  await tester.tap(
    find.descendant(of: form, matching: find.byType(ElevatedButton)),
  );
  await tester.pump();
}
