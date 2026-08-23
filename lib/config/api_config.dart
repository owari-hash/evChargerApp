/// Where the driver-facing API lives.
///
/// The app talks to the **driver API** (`/app-api/...`) served by the Next.js
/// app in `evChargerKiosk`, not to the CSMS REST API (`/api/...`) in
/// `evChargerBack`. The CSMS surface is for operators and charge points; the
/// driver surface is the one that knows about accounts, wallets and sessions.
///
/// Every build talks to the live driver API by default, debug included, so the
/// accounts drivers already have on the kiosk website work in the app without
/// any flag. Pointing a build at a local stack is the opt-in case:
///
/// ```sh
/// # iOS simulator / desktop
/// flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3100
/// # Android emulator reaches the host on 10.0.2.2
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3100
/// ```
class ApiConfig {
  const ApiConfig._();

  /// Set at build time; wins over every default below when non-empty.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String _productionBaseUrl = 'https://eplug.mn';

  /// Origin every request is built against, without a trailing slash.
  ///
  /// A debug build used to default to localhost, which silently pointed the app
  /// at a different database from the one the kiosk website uses — accounts
  /// looked like they were not syncing when in truth they were never in the
  /// same store. Production is the default now precisely so that cannot happen
  /// by accident.
  static String get baseUrl => _override.isNotEmpty
      ? _stripTrailingSlashes(_override)
      : _productionBaseUrl;

  /// Absolute URL for a driver-API path, e.g. `uri('/auth/login')`.
  static Uri uri(String path, [Map<String, String>? query]) {
    final String suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$baseUrl/app-api$suffix',
    ).replace(queryParameters: (query == null || query.isEmpty) ? null : query);
  }

  static String _stripTrailingSlashes(String value) =>
      value.replaceFirst(RegExp(r'/+$'), '');
}
