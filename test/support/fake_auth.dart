import 'dart:convert';

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
  'idTags': <String>['TAG-001'],
  'locale': 'mn',
};

/// Credentials that the stub accepts. Anything else comes back 401.
const String kTestIdentifier = '99118844';
const String kTestPassword = 'Charge123';

/// An [AuthService] wired to an in-memory driver API, so widget tests can sign
/// in and out without a server or the platform keychain.
///
/// Pass [startSignedIn] to begin with a stored session, the way a returning
/// driver launches the app.
ApiClient fakeApiClient({bool startSignedIn = false}) {
  final SessionStore store = InMemorySessionStore();
  if (startSignedIn) store.write('evapp_session=stub');
  return ApiClient(sessionStore: store, httpClient: _stubClient());
}

AuthService fakeAuthService({bool startSignedIn = false}) =>
    AuthService(client: fakeApiClient(startSignedIn: startSignedIn));

MockClient _stubClient() {
  return MockClient((http.Request request) async {
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

    http.Response fail(int status, String message) => http.Response(
      jsonEncode(<String, String>{'error': message}),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

    if (path.endsWith('/auth/login')) {
      final bool matches =
          body['identifier'] == kTestIdentifier &&
          body['password'] == kTestPassword;
      return matches
          ? ok(<String, dynamic>{'user': kTestUser})
          : fail(401, 'И-мэйл/утасны дугаар эсвэл нууц үг буруу байна');
    }

    if (path.endsWith('/auth/register')) {
      return ok(<String, dynamic>{
        'user': kTestUser,
        'verification': <String, dynamic>{
          'sent': true,
          'destination': 'b••@example.com',
        },
      });
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

    if (path.endsWith('/account/password')) {
      return ok(<String, dynamic>{'ok': true});
    }

    return fail(404, 'Хүсэлт олдсонгүй');
  });
}

/// Fills in the sign-in form with credentials the stub accepts and submits it.
///
/// Focus is dropped before the tap on purpose: `enterText` leaves a text
/// selection handle in the overlay, which on a tall phone lands on top of the
/// pinned submit button and swallows the tap.
Future<void> signInThroughUi(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), kTestIdentifier);
  await tester.enterText(find.byType(TextField).at(1), kTestPassword);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();

  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
}
