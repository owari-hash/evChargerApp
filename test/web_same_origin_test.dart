import 'dart:convert';

import 'package:evchargerapp/config/api_config.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A browser build has no CORS grant from the driver API, so it must call
/// `/app-api` on its own origin and let the browser carry the session cookie —
/// exactly what the kiosk website does.
void main() {
  group('ApiConfig.resolveBaseUrl', () {
    test('a web build asks the origin that served the page', () {
      expect(
        ApiConfig.resolveBaseUrl(
          override: '',
          isWeb: true,
          pageOrigin: 'http://localhost:5555',
        ),
        'http://localhost:5555',
      );
    });

    test('native builds keep talking to production', () {
      expect(
        ApiConfig.resolveBaseUrl(
          override: '',
          isWeb: false,
          pageOrigin: '',
        ),
        'https://eplug.mn',
      );
    });

    test('an explicit API_BASE_URL still wins everywhere', () {
      expect(
        ApiConfig.resolveBaseUrl(
          override: 'http://127.0.0.1:3100/',
          isWeb: true,
          pageOrigin: 'http://localhost:5555',
        ),
        'http://127.0.0.1:3100',
      );
    });
  });

  group('ApiClient cookie handling', () {
    MockClient recorder(List<http.Request> log) =>
        MockClient((http.Request request) async {
          log.add(request);
          return http.Response(
            jsonEncode(<String, bool>{'ok': true}),
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'set-cookie': 'evapp_session=fresh; Path=/; HttpOnly',
            },
          );
        });

    test('in a browser the page never touches the cookie itself', () async {
      final List<http.Request> log = <http.Request>[];
      final SessionStore store = InMemorySessionStore();
      final ApiClient client = ApiClient(
        httpClient: recorder(log),
        sessionStore: store,
        browserManagesCookies: true,
      );

      // The httpOnly cookie is invisible to page scripts, so only the server
      // can say whether a session exists.
      expect(await client.hasSession, isTrue);

      await client.post('/auth/login', body: <String, String>{'pin': '1234'});
      await client.get('/auth/me');

      expect(log.map((http.Request r) => r.headers['Cookie']), everyElement(isNull));
      expect(await store.read(), isNull);
    });

    test('on a device the captured cookie is replayed', () async {
      final List<http.Request> log = <http.Request>[];
      final ApiClient client = ApiClient(
        httpClient: recorder(log),
        sessionStore: InMemorySessionStore(),
        browserManagesCookies: false,
      );

      expect(await client.hasSession, isFalse);
      await client.post('/auth/login');
      await client.get('/auth/me');

      expect(log.last.headers['Cookie'], 'evapp_session=fresh');
      expect(await client.hasSession, isTrue);
    });
  });
}
