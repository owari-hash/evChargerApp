import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_store.dart';

/// A driver API call that did not succeed.
///
/// The API answers every failure with the same envelope —
/// `{ "error": "...", "fields": { "email": "..." } }` — so the form can show a
/// banner and mark the offending inputs from one object.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.fields = const <String, String>{},
  });

  /// 0 when the request never reached the server.
  final int statusCode;

  final String message;

  /// Per-field messages, keyed by the field name the API validated.
  final Map<String, String> fields;

  bool get isUnauthorized => statusCode == 401;
  bool get isOffline => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON client for `/app-api/...` that carries the driver's session.
///
/// The driver API authenticates with an httpOnly cookie rather than a bearer
/// token, because it was built for the kiosk web app where the browser manages
/// the jar. Nothing here is browser-specific though: the cookie is captured off
/// the login response, persisted, and replayed on later requests.
class ApiClient {
  ApiClient({http.Client? httpClient, SessionStore? sessionStore})
    : _http = httpClient ?? http.Client(),
      _sessions = sessionStore ?? SecureSessionStore();

  /// The client the app runs on. Every service shares it so they all speak with
  /// the same session cookie — signing in once signs in everywhere.
  static final ApiClient shared = ApiClient();

  /// Matches `SESSION_COOKIE_NAME` in evChargerKiosk (default `evapp_session`).
  static const String sessionCookieName = 'evapp_session';

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _http;
  final SessionStore _sessions;

  String? _cookie;
  bool _restored = false;

  /// True once a session cookie is held, whether restored from disk or just
  /// issued. Says nothing about whether the server still honours it.
  Future<bool> get hasSession async => (await _currentCookie()) != null;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
  }) => _send('DELETE', path, query: query);

  /// Forgets the session locally. Callers that also want the server to forget
  /// it should POST `/auth/logout` first.
  Future<void> clearSession() async {
    _cookie = null;
    _restored = true;
    await _sessions.clear();
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final Uri url = ApiConfig.uri(path, query);
    final String? cookie = await _currentCookie();

    final http.Request request = http.Request(method, url)
      ..headers['Accept'] = 'application/json';
    if (cookie != null) request.headers['Cookie'] = cookie;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Сервер удаан хариулж байна. Дахин оролдоно уу.',
      );
    } on SocketException {
      throw const ApiException(
        statusCode: 0,
        message: 'Интернэт холболтоо шалгаад дахин оролдоно уу.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        message: 'Интернэт холболтоо шалгаад дахин оролдоно уу.',
      );
    }

    await _captureSessionCookie(response);
    return _decode(response);
  }

  /// Reads a session token off the response and persists it.
  ///
  /// `http` folds repeated `Set-Cookie` headers into one comma-joined string,
  /// which is why this looks for the named cookie rather than splitting on
  /// commas — a cookie's own `Expires` date contains one.
  Future<void> _captureSessionCookie(http.Response response) async {
    final String? raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;

    final Match? match = RegExp(
      '(?:^|[,;]\\s*)$sessionCookieName=([^;,]*)',
    ).firstMatch(raw);
    if (match == null) return;

    final String value = match.group(1) ?? '';
    if (value.isEmpty) {
      // The server clears the session by setting an empty value.
      await clearSession();
      return;
    }

    _cookie = '$sessionCookieName=$value';
    _restored = true;
    await _sessions.write(_cookie!);
  }

  Future<String?> _currentCookie() async {
    if (!_restored) {
      _cookie = await _sessions.read();
      _restored = true;
    }
    return _cookie;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload = const <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) payload = parsed;
      } catch (_) {
        // A non-JSON body means something in front of the API answered —
        // a proxy error page, say. Fall through to the status-code message.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return payload;

    throw ApiException(
      statusCode: response.statusCode,
      message: (payload['error'] ?? _fallbackMessage(response.statusCode))
          .toString(),
      fields: _fields(payload['fields']),
    );
  }

  static Map<String, String> _fields(dynamic raw) {
    if (raw is! Map) return const <String, String>{};
    return raw.map(
      (dynamic key, dynamic value) =>
          MapEntry<String, String>(key.toString(), value.toString()),
    );
  }

  static String _fallbackMessage(int status) {
    if (status == 404) return 'Хүсэлт олдсонгүй. Серверийн хаягаа шалгана уу.';
    if (status >= 500) return 'Сервер дээр алдаа гарлаа. Дараа оролдоно уу.';
    return 'Хүсэлт амжилтгүй боллоо ($status).';
  }
}
