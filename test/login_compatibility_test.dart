import 'dart:convert';

import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth.dart';

/// Builds an auth service whose stub records what the app actually posted.
(AuthService, List<Map<String, dynamic>>) _recording(
  http.Response Function(Map<String, dynamic> body) respond,
) {
  final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
  final MockClient client = MockClient((http.Request request) async {
    final Map<String, dynamic> body =
        jsonDecode(request.body) as Map<String, dynamic>;
    sent.add(body);
    return respond(body);
  });
  return (
    AuthService(
      client: ApiClient(
        httpClient: client,
        sessionStore: InMemorySessionStore(),
      ),
    ),
    sent,
  );
}

http.Response _ok() => http.Response(
  jsonEncode(<String, dynamic>{'user': kTestUser}),
  200,
  headers: <String, String>{
    'content-type': 'application/json',
    'set-cookie': 'evapp_session=stub; Path=/',
  },
);

/// What a kiosk deployment that predates phone login answers when the body
/// carries no `email`.
http.Response _oldServer(Map<String, dynamic> body) {
  if (body['email'] is String) return _ok();
  return http.Response(
    jsonEncode(<String, dynamic>{
      'error': 'Тэмдэглэсэн талбаруудаа шалгана уу',
      'fields': <String, String>{
        'email': 'Invalid input: expected string, received undefined',
      },
    }),
    400,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  test(
    'an email is sent under both keys, so an old server still accepts it',
    () async {
      final (AuthService auth, List<Map<String, dynamic>> sent) = _recording(
        (_) => _ok(),
      );

      await auth.signIn(identifier: 'bat@example.com', password: 'Charge123');

      expect(sent, hasLength(1));
      expect(sent.single['identifier'], 'bat@example.com');
      expect(sent.single['email'], 'bat@example.com');
    },
  );

  test(
    'a phone number is sent only as identifier, never as an email',
    () async {
      final (AuthService auth, List<Map<String, dynamic>> sent) = _recording(
        (_) => _ok(),
      );

      await auth.signIn(identifier: '99118844', password: 'Charge123');

      expect(sent.single['identifier'], '99118844');
      // Posting a phone number under `email` would fail the address validator.
      expect(sent.single.containsKey('email'), isFalse);
    },
  );

  test(
    'signing in by email works against a server without phone support',
    () async {
      final (AuthService auth, _) = _recording(_oldServer);

      final user = await auth.signIn(
        identifier: 'bat@example.com',
        password: 'Charge123',
      );

      expect(user.email, 'bat@example.com');
    },
  );

  test(
    'a phone on an old server explains itself instead of "check the fields"',
    () async {
      final (AuthService auth, _) = _recording(_oldServer);

      await expectLater(
        auth.signIn(identifier: '99118844', password: 'Charge123'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            contains('И-мэйл хаягаараа нэвтэрнэ үү'),
          ),
        ),
      );
    },
  );
}
