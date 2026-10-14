import 'package:flutter/foundation.dart';

import '../models/charging_session.dart';
import 'api_client.dart';

/// Charging history for the signed-in driver, from `/app-api/sessions`.
class SessionsService {
  SessionsService({ApiClient? client}) : _client = client ?? ApiClient.shared;

  static final SessionsService instance = SessionsService();

  final ApiClient _client;

  /// Ticks whenever a charge was just started somewhere in the app (the QR
  /// flow, today). The dashboard listens so a session started from another
  /// screen shows up immediately rather than waiting for its own poll —
  /// starting a remote session does not create a transaction instantly, so
  /// there is nothing else to react to until the charge point reports in.
  final ValueNotifier<int> sessionStarted = ValueNotifier<int>(0);

  void notifySessionStarted() => sessionStarted.value++;

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

  /// Requests a real e-Barimt tax receipt for a past session — the same
  /// endpoint the kiosk web app's receipt flow calls, not a device-side
  /// stand-in. [customerTin] is required for [EBarimtType.b2b].
  Future<ChargingSession> requestEbarimt(
    int transactionId, {
    required EBarimtType type,
    String? customerTin,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/sessions/$transactionId/ebarimt',
      body: <String, dynamic>{
        'type': type == EBarimtType.b2b ? 'B2B_RECEIPT' : 'B2C_RECEIPT',
        if (customerTin != null) 'customerTin': customerTin,
      },
    );
    return ChargingSession.fromJson(body['session'] as Map<String, dynamic>);
  }
}
