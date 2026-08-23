import '../models/charging_session.dart';
import 'api_client.dart';

/// Charging history for the signed-in driver, from `/app-api/sessions`.
class SessionsService {
  SessionsService({ApiClient? client}) : _client = client ?? ApiClient.shared;

  static final SessionsService instance = SessionsService();

  final ApiClient _client;

  /// Most recent first. Comes back empty when no charge tag is linked yet —
  /// sessions are matched by tag, so an account without one has no history.
  Future<List<ChargingSession>> list({int limit = 50}) async {
    final Map<String, dynamic> body = await _client.get(
      '/sessions',
      query: <String, String>{'limit': '$limit'},
    );

    return (body['sessions'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChargingSession.fromJson)
        .toList(growable: false);
  }

  /// Asks the charge point to end a session over OCPP.
  ///
  /// Returns the charge point's own answer — usually `Accepted`, which means it
  /// has taken the request, not that charging has already stopped. Only the
  /// account holding the tag that started the charge may stop it.
  Future<String> stop(int transactionId) async {
    final Map<String, dynamic> body = await _client.post(
      '/sessions/$transactionId/stop',
    );
    return (body['status'] ?? 'Accepted').toString();
  }
}
