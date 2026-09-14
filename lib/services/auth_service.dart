import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'api_client.dart';

/// What the API reports after texting a code.
class CodeSent {
  const CodeSent({required this.destination, this.devCode});

  /// Masked number the code went to, e.g. `********8844`.
  final String destination;

  /// Only from a development server with no SMS provider, which echoes the
  /// code back instead of texting it.
  final String? devCode;

  factory CodeSent.fromJson(Map<String, dynamic> json) {
    final String code = (json['devCode'] ?? '').toString();
    return CodeSent(
      destination: (json['destination'] ?? '').toString(),
      devCode: code.isEmpty ? null : code,
    );
  }
}

/// Driver accounts: sign in with a phone number and PIN, sign up, reset a
/// forgotten PIN, restore and end a session.
///
/// Sign-up and a PIN reset are the same three steps — text a code, check it,
/// set a PIN — and both end with the driver signed in.
///
/// Talks to the `/app-api/auth/*` routes in `evChargerKiosk`.
class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient.shared;

  /// The instance the app runs on. Tests build their own with a fake client.
  static final AuthService instance = AuthService();

  final ApiClient _client;

  /// The signed-in driver, or null. Listenable so the app frame can rebuild
  /// when a session starts or ends.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  bool get isSignedIn => currentUser.value != null;

  /// The API normalises the number, so local input like `9911 8844` is fine.
  Future<AuthUser> signIn({required String phone, required String pin}) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/login',
      body: <String, dynamic>{'phone': phone.trim(), 'pin': pin},
    );
    return _adopt(body['user']);
  }

  /// Sign-up, step 1. Only called once the driver has accepted the terms.
  Future<CodeSent> sendSignupCode(String phone) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/signup/send-code',
      body: <String, dynamic>{'phone': phone.trim(), 'acceptTerms': true},
    );
    return CodeSent.fromJson(body);
  }

  /// Sign-up, step 2. Returns the ticket step 3 needs; no account exists yet.
  Future<String> verifySignupCode({
    required String phone,
    required String code,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/signup/verify',
      body: <String, dynamic>{'phone': phone.trim(), 'code': code.trim()},
    );
    return _ticket(body['signupTicket']);
  }

  /// Sign-up, step 3: creates the account and signs the driver straight in —
  /// the API sets the session cookie on this response.
  Future<AuthUser> completeSignup({
    required String ticket,
    required String pin,
    required String confirmPin,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/signup/complete',
      body: <String, dynamic>{
        'signupTicket': ticket,
        'pin': pin,
        'confirmPin': confirmPin,
      },
    );
    return _adopt(body['user']);
  }

  /// PIN reset, step 1: texts a code to a registered number.
  Future<CodeSent> sendPinResetCode(String phone) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/pin/forgot',
      body: <String, dynamic>{'phone': phone.trim()},
    );
    return CodeSent.fromJson(body);
  }

  /// PIN reset, step 2. Returns the ticket step 3 needs.
  Future<String> verifyPinResetCode({
    required String phone,
    required String code,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/pin/verify',
      body: <String, dynamic>{'phone': phone.trim(), 'code': code.trim()},
    );
    return _ticket(body['resetTicket']);
  }

  /// PIN reset, step 3: saves the new PIN, signs out every other device and
  /// signs this one in.
  Future<AuthUser> resetPin({
    required String ticket,
    required String pin,
    required String confirmPin,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/pin/reset',
      body: <String, dynamic>{
        'resetTicket': ticket,
        'pin': pin,
        'confirmPin': confirmPin,
      },
    );
    return _adopt(body['user']);
  }

  /// Re-establishes a session saved on a previous launch.
  ///
  /// Returns null when there is nothing stored, when the cookie has expired, or
  /// when the server cannot be reached — the caller shows the sign-in screen in
  /// all three cases rather than blocking on a network round trip.
  Future<AuthUser?> restoreSession() async {
    if (!await _client.hasSession) return null;
    try {
      final Map<String, dynamic> body = await _client.get('/auth/me');
      return _adopt(body['user']);
    } on ApiException catch (error) {
      // Only a rejected cookie is worth throwing away. An offline launch should
      // keep the session so it still works once there is signal.
      if (error.isUnauthorized) await _client.clearSession();
      currentUser.value = null;
      return null;
    }
  }

  /// Ends the session on the server, then locally. The local half runs even if
  /// the request fails, so "sign out" always signs the driver out.
  Future<void> signOut() async {
    try {
      await _client.post('/auth/logout');
    } on ApiException {
      /* Signing out locally is what matters. */
    } finally {
      await _client.clearSession();
      currentUser.value = null;
    }
  }

  static String _ticket(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    throw const ApiException(
      statusCode: 0,
      message: 'Сервер санамсаргүй хариу буцаалаа.',
    );
  }

  AuthUser _adopt(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 0,
        message: 'Сервер санамсаргүй хариу буцаалаа.',
      );
    }
    final AuthUser user = AuthUser.fromJson(json);
    currentUser.value = user;
    return user;
  }
}
