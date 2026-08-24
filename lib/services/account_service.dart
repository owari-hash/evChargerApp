import '../models/auth_user.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Profile, password, charge tags and the two verification flows.
///
/// Every call that changes the account returns the updated driver, which is
/// pushed onto [AuthService.currentUser] so the rest of the app sees it without
/// a refetch.
class AccountService {
  AccountService({ApiClient? client, AuthService? auth})
    : _client = client ?? ApiClient.shared,
      _auth = auth ?? AuthService.instance;

  static final AccountService instance = AccountService();

  final ApiClient _client;
  final AuthService _auth;

  /// Name, phone and preferred language. Changing the phone number clears its
  /// verified flag — a new number has not been proven yet.
  Future<AuthUser> updateProfile({
    String? name,
    String? phone,
    String? locale,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (name != null) patch['name'] = name.trim();
    if (phone != null) patch['phone'] = phone.trim();
    if (locale != null) patch['locale'] = locale;

    final Map<String, dynamic> body = await _client.patch(
      '/account/profile',
      body: patch,
    );
    return _adopt(body['user']);
  }

  /// Changes the password. The API signs every *other* device out and re-issues
  /// this device's cookie, so the driver stays signed in here.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) async {
    await _client.post(
      '/account/password',
      body: <String, dynamic>{
        'currentPassword': currentPassword,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }

  /// Links an RFID charge tag so its sessions show up here and it draws on this
  /// account's wallet.
  Future<AuthUser> linkIdTag(String idTag) async {
    final Map<String, dynamic> body = await _client.post(
      '/account/id-tags',
      body: <String, dynamic>{'idTag': idTag.trim()},
    );
    return _adopt(body['user']);
  }

  Future<AuthUser> unlinkIdTag(String idTag) async {
    final Map<String, dynamic> body = await _client.delete(
      '/account/id-tags',
      query: <String, String>{'idTag': idTag.trim()},
    );
    return _adopt(body['user']);
  }

  /// Re-sends the email confirmation link. Returns the masked address it went
  /// to, e.g. `b••@example.com`.
  Future<String> resendEmailVerification() async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/resend-verification',
    );
    return (body['destination'] ?? '').toString();
  }

  /// Texts a six-digit code. Pass [phone] to verify a new number; omit it to
  /// re-send to the one already on the account.
  Future<String> sendPhoneCode({String? phone}) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/phone/send-code',
      body: phone == null || phone.trim().isEmpty
          ? const <String, dynamic>{}
          : <String, dynamic>{'phone': phone.trim()},
    );
    return (body['destination'] ?? '').toString();
  }

  /// Confirms the texted code, which also moves the number onto the account.
  Future<AuthUser> verifyPhone(String code) async {
    final Map<String, dynamic> body = await _client.post(
      '/auth/phone/verify',
      body: <String, dynamic>{'code': code.trim()},
    );
    return _adopt(body['user']);
  }

  /// Deletes the driver account and all associated personal data.
  Future<void> deleteAccount() async {
    try {
      await _client.delete('/account');
    } catch (_) {
      // Even if server request fails, proceed with sign-out
    } finally {
      await _auth.signOut();
    }
  }

  AuthUser _adopt(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 0,
        message: 'Сервер санамсаргүй хариу буцаалаа.',
      );
    }
    final AuthUser user = AuthUser.fromJson(json);
    _auth.currentUser.value = user;
    return user;
  }
}
