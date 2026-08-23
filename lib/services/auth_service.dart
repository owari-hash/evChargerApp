import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'api_client.dart';

/// What `/auth/register` reports back about the verification email it sent.
class VerificationNotice {
  const VerificationNotice({required this.sent, required this.destination});

  /// False when the account was created but the mail could not be delivered.
  /// The address can still be confirmed later from the account screen, so this
  /// is a notice rather than a failure.
  final bool sent;

  /// Masked address the link went to, e.g. `d••••r@example.com`.
  final String destination;

  factory VerificationNotice.fromJson(Map<String, dynamic> json) {
    return VerificationNotice(
      sent: json['sent'] == true,
      destination: (json['destination'] ?? '').toString(),
    );
  }
}

/// Result of a successful sign-up.
class RegisterResult {
  const RegisterResult({required this.user, this.verification});

  final AuthUser user;
  final VerificationNotice? verification;
}

/// Driver accounts: sign in, sign up, restore and end a session.
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

  /// Signs in with a phone number **or** an email address; the API decides
  /// which it was given.
  Future<AuthUser> signIn({
    required String identifier,
    required String password,
  }) async {
    final String id = identifier.trim();
    final bool looksLikeEmail = id.contains('@');

    try {
      final Map<String, dynamic> body = await _client.post(
        '/auth/login',
        body: <String, dynamic>{
          'identifier': id,
          // Deployments that predate phone login only understand `email` and
          // reject a body without it. Sending both keys means one build works
          // against an old server and a new one alike; the new server prefers
          // `identifier`, the old one ignores the key it does not know.
          if (looksLikeEmail) 'email': id,
          'password': password,
          'remember': true,
        },
      );
      return _adopt(body['user']);
    } on ApiException catch (error) {
      // A phone number sent to a server that still requires an address comes
      // back as a validation failure on `email`, which would otherwise surface
      // as an unhelpful "check the marked fields".
      if (!looksLikeEmail &&
          error.statusCode == 400 &&
          error.fields.containsKey('email')) {
        throw const ApiException(
          statusCode: 400,
          message:
              'Энэ сервер утсаар нэвтрэхийг дэмжихгүй байна. И-мэйл хаягаараа нэвтэрнэ үү.',
          fields: <String, String>{'identifier': 'И-мэйл хаягаа оруулна уу'},
        );
      }
      rethrow;
    }
  }

  /// Creates an account and signs the new driver straight in — the API sets the
  /// session cookie on the register response, so there is no second round trip.
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/register',
      body: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
        'acceptTerms': true,
      },
    );

    final AuthUser user = _adopt(body['user']);
    final dynamic verification = body['verification'];
    return RegisterResult(
      user: user,
      verification: verification is Map<String, dynamic>
          ? VerificationNotice.fromJson(verification)
          : null,
    );
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

  /// Sends a reset link or SMS code. The API answers the same way whether or
  /// not an account matched, so this never reveals who is registered.
  Future<String> requestPasswordReset(String identifier) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/forgot-password',
      body: <String, dynamic>{
        'identifier': identifier.trim(),
        'channel': 'auto',
      },
    );
    return (body['message'] ?? '').toString();
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
