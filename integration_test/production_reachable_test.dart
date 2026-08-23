import 'package:evchargerapp/config/api_config.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Proves the default build really reaches the live driver API at eplug.mn and
/// that the login body it sends is one that server accepts.
///
/// Deliberately uses credentials that cannot exist, so nothing is created or
/// changed on the production system:
///
/// ```sh
/// flutter test integration_test/production_reachable_test.dart -d <simulator-id>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the default build signs in against the live kiosk API',
      (WidgetTester tester) async {
    expect(ApiConfig.baseUrl, 'https://eplug.mn');
    expect(
      ApiConfig.uri('/auth/login').toString(),
      'https://eplug.mn/app-api/auth/login',
    );

    final AuthService auth = AuthService(client: ApiClient());

    ApiException? failure;
    try {
      await auth.signIn(
        identifier: 'definitely-not-a-real-account@example.invalid',
        password: 'not-a-real-password',
      );
    } on ApiException catch (error) {
      failure = error;
    }

    expect(failure, isNotNull, reason: 'a bogus account must not sign in');

    // 401 is the answer we want: the server understood the body and rejected
    // the credentials. A 400 would mean it could not parse what the app sent —
    // which is exactly what happened while the app posted `identifier` alone.
    expect(
      failure!.statusCode,
      401,
      reason: 'got ${failure.statusCode}: ${failure.message}',
    );
  });
}
