import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// What the device offers: Face ID on iPhone, a fingerprint on Android (and on
/// Touch ID iPhones).
enum BiometricKind { face, fingerprint }

/// The phone number and PIN remembered for biometric sign-in.
class SavedCredentials {
  const SavedCredentials({required this.phone, required this.pin});

  final String phone;
  final String pin;
}

/// The device's own biometric check, behind an interface so tests need no
/// device.
abstract class BiometricAuthenticator {
  /// Null when there is no sensor or nothing is enrolled.
  Future<BiometricKind?> availableKind();

  /// Shows the system Face ID / fingerprint prompt. False if it was cancelled
  /// or failed.
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricKind?> availableKind() async {
    try {
      if (!await _auth.canCheckBiometrics) return null;
      final List<BiometricType> enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isEmpty) return null;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return enrolled.contains(BiometricType.face)
            ? BiometricKind.face
            : BiometricKind.fingerprint;
      }
      // Many Android devices report only a strength class (strong / weak),
      // not the sensor, so Android is always presented as a fingerprint.
      return BiometricKind.fingerprint;
    } catch (_) {
      // No plugin (tests, desktop) or the platform refused: no biometrics.
      return null;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Where the remembered credentials live.
abstract class CredentialVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The Keychain on iOS (this device only, never synced to iCloud) and
/// EncryptedSharedPreferences on Android.
class SecureCredentialVault implements CredentialVault {
  const SecureCredentialVault();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      /* Biometric sign-in simply stays off. */
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      /* Nothing to do. */
    }
  }
}

class InMemoryCredentialVault implements CredentialVault {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Sign in with Face ID or a fingerprint instead of typing the PIN.
///
/// Turning it on remembers the phone number and PIN in the device's secure
/// storage, behind the system biometric prompt; nothing extra is sent to or
/// stored on the server. Sign-in then reads them back and signs in with them
/// exactly as if they had been typed, so a PIN changed elsewhere simply stops
/// working and the caller turns this off again.
class BiometricService {
  BiometricService({
    BiometricAuthenticator? authenticator,
    CredentialVault? vault,
  }) : _authenticator = authenticator ?? LocalBiometricAuthenticator(),
       _vault = vault ?? const SecureCredentialVault();

  static final BiometricService instance = BiometricService();

  static const String _phoneKey = 'biometric_phone';
  static const String _pinKey = 'biometric_pin';
  static const String _declinedKey = 'biometric_declined';

  final BiometricAuthenticator _authenticator;
  final CredentialVault _vault;

  Future<BiometricKind?> availableKind() => _authenticator.availableKind();

  Future<bool> isEnabled() async =>
      await _vault.read(_phoneKey) != null && await _vault.read(_pinKey) != null;

  /// True once the driver answered "not now", so they are not asked after
  /// every sign-in. Turning it on from the security screen still works.
  Future<bool> wasDeclined() async => await _vault.read(_declinedKey) == 'true';

  Future<void> markDeclined() => _vault.write(_declinedKey, 'true');

  /// Asks for Face ID / a fingerprint, then remembers the credentials. False if
  /// the driver cancelled the prompt.
  Future<bool> enable({
    required String phone,
    required String pin,
    required String reason,
  }) async {
    if (!await _authenticator.authenticate(reason)) return false;
    await _save(phone: phone, pin: pin);
    await _vault.delete(_declinedKey);
    return true;
  }

  /// Keeps the remembered PIN current after it was changed or reset here. Does
  /// nothing while biometric sign-in is off.
  Future<void> refresh({required String phone, required String pin}) async {
    if (await isEnabled()) await _save(phone: phone, pin: pin);
  }

  /// Asks for Face ID / a fingerprint and hands back the remembered
  /// credentials, or null if it is off or the prompt was cancelled.
  Future<SavedCredentials?> unlock({required String reason}) async {
    final String? phone = await _vault.read(_phoneKey);
    final String? pin = await _vault.read(_pinKey);
    if (phone == null || pin == null) return null;
    if (!await _authenticator.authenticate(reason)) return null;
    return SavedCredentials(phone: phone, pin: pin);
  }

  Future<void> disable() async {
    await _vault.delete(_phoneKey);
    await _vault.delete(_pinKey);
  }

  Future<void> _save({required String phone, required String pin}) async {
    await _vault.write(_phoneKey, phone.trim());
    await _vault.write(_pinKey, pin);
  }
}
