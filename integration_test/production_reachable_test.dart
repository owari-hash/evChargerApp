import 'package:evchargerapp/config/api_config.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Proves the default build really reaches the live driver API at eplug.mn and
/// that the login body it sends is one that server accepts.
///
/// Deliberately uses a number that is not registered, so nothing is created,
/// changed or locked on the production system:
///
/// ```sh
/// flutter test integration_test/production_reachable_test.dart -d <simulator-id>
/// ```
///
/// Needs the PIN sign-in kiosk deployed: an older server rejects a body without
/// `email` with a 400.
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
      await auth.signIn(phone: '80000000', pin: '0000');
    } on ApiException catch (error) {
      failure = error;
    }

    expect(failure, isNotNull, reason: 'a bogus account must not sign in');

    // 401 is the answer we want: the server understood the body and rejected
    // the credentials. A 400 would mean it could not parse what the app sent.
    expect(
      failure!.statusCode,
      401,
      reason: 'got ${failure.statusCode}: ${failure.message}',
    );
  });
}
