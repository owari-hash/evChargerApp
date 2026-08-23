import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the driver API's session cookie is kept between launches.
///
/// Abstracted so widget tests can swap in [InMemorySessionStore] instead of
/// reaching for the platform keychain, which has no binding under `flutter test`.
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String cookie);
  Future<void> clear();
}

/// Keychain on iOS/macOS, EncryptedSharedPreferences on Android.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const String _key = 'driver_session_cookie';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // A keychain that refuses to open should log the driver out, not crash
      // the launch. They can sign in again.
      return null;
    }
  }

  @override
  Future<void> write(String cookie) async {
    try {
      await _storage.write(key: _key, value: cookie);
    } catch (_) {
      // Session survives in memory for this launch only.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      /* Nothing to do. */
    }
  }
}

/// Non-persistent store, for tests and for targets without secure storage.
class InMemorySessionStore implements SessionStore {
  String? _cookie;

  @override
  Future<String?> read() async => _cookie;

  @override
  Future<void> write(String cookie) async => _cookie = cookie;

  @override
  Future<void> clear() async => _cookie = null;
}
