import 'package:evchargerapp/services/biometric_service.dart';

/// Stands in for the device's Face ID / fingerprint prompt.
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.kind = BiometricKind.face, this.succeeds = true});

  /// Null means the device has no biometrics.
  BiometricKind? kind;

  /// Whether the prompt "recognises" the driver.
  bool succeeds;

  /// How many times the prompt was shown.
  int prompts = 0;

  @override
  Future<BiometricKind?> availableKind() async => kind;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeeds;
  }
}

/// A [BiometricService] with a fake prompt and an in-memory vault.
BiometricService fakeBiometrics({
  BiometricKind? kind = BiometricKind.face,
  bool succeeds = true,
}) => BiometricService(
  authenticator: FakeBiometricAuthenticator(kind: kind, succeeds: succeeds),
  vault: InMemoryCredentialVault(),
);
