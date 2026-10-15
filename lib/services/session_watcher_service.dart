import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/charging_session.dart';
import 'sessions_service.dart';

enum SessionEventType { started, stopped }

/// A charge on the signed-in driver's own tag beginning or ending.
class SessionEvent {
  const SessionEvent({
    required this.type,
    required this.session,
    required this.confirmedInApp,
  });

  final SessionEventType type;
  final ChargingSession session;

  /// The app already told the driver about this one itself — the QR flow's
  /// «Цэнэглэлт эхэллээ» snackbar, the dashboard's receipt sheet — so it
  /// belongs in the bell's history but should not pop up a second time.
  final bool confirmedInApp;
}

/// Polls the signed-in driver's recent sessions and reports when one starts
/// or stops — from the app's QR flow, an RFID card at the station or the
/// website alike, since all of them end up in `/app-api/sessions`.
///
/// Same approach as [WalletWatcherService]: there is no driver-facing live
/// event stream, so this keeps `transactionId → last known status` and diffs
/// each poll against it.
///
/// The first list seen for a driver is a silent baseline. Sessions already
/// running or already over at that point never notify; only what changes
/// after it does. The baseline lives in memory for as long as the same driver
/// stays signed in, so a charge that ends while the app is in the background
/// is still reported when it comes back, and is reset for anyone else.
class SessionWatcherService {
  SessionWatcherService({
    SessionsService? sessions,
    this.pollInterval = const Duration(seconds: 15),
    this.followUpDelays = const <Duration>[
      Duration(seconds: 3),
      Duration(seconds: 8),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
  }) : _sessions = sessions ?? SessionsService.instance;

  static final SessionWatcherService instance = SessionWatcherService();

  /// How many of the newest sessions each poll asks for.
  static const int pollLimit = 10;

  /// How long after the app itself asked for a start or a stop the matching
  /// event still counts as [SessionEvent.confirmedInApp].
  static const Duration localActionWindow = Duration(minutes: 2);

  final SessionsService _sessions;
  final Duration pollInterval;

  /// Extra checks after the app's own start or stop: the charge point takes
  /// a few seconds to report the transaction in, and waiting for the next
  /// regular poll would make the pop-up feel unrelated to the tap.
  final List<Duration> followUpDelays;

  Timer? _timer;
  final List<Timer> _followUps = <Timer>[];
  void Function(SessionEvent event)? _onEvent;

  String? _userId;

  /// `transactionId → status` as of the last list seen. Null until the
  /// baseline for [_userId] has been taken.
  Map<int, SessionStatus>? _known;

  /// The newest transaction in the baseline. A session missing from the map
  /// counts as new only above this, so one sliding into the [pollLimit]
  /// window from further back (after a deletion, say) is never news.
  int _baselineMaxId = 0;

  DateTime? _localStartAt;
  final Map<int, DateTime> _localStops = <int, DateTime>{};

  Future<void>? _inFlight;

  bool get isRunning => _timer != null;

  /// Starts (or resumes) watching [userId]'s sessions and checks right away.
  ///
  /// The same driver again keeps what was already known, so resuming from
  /// the background reports whatever finished meanwhile. A different driver
  /// starts over from a fresh, silent baseline.
  void start({
    required String userId,
    required void Function(SessionEvent event) onEvent,
  }) {
    if (_userId != userId) _reset(userId);
    _onEvent = onEvent;
    if (_timer == null) {
      _sessions.sessionStarted.addListener(_onAppStartedCharge);
      _timer = Timer.periodic(pollInterval, (_) => unawaited(checkNow()));
    }
    unawaited(checkNow());
  }

  /// Pauses polling — the app went to the background. What is known is kept.
  void stop() {
    if (_timer != null) {
      _sessions.sessionStarted.removeListener(_onAppStartedCharge);
    }
    _timer?.cancel();
    _timer = null;
    _cancelFollowUps();
  }

  /// Signed out: stops and forgets everything about the previous driver.
  void signOut() {
    stop();
    _reset(null);
    _onEvent = null;
  }

  void _reset(String? userId) {
    _userId = userId;
    _known = null;
    _baselineMaxId = 0;
    _localStartAt = null;
    _localStops.clear();
  }

  /// The app's own QR flow asked a charger to start.
  ///
  /// [SessionsService.sessionStarted] ticks for that, so this is wired up
  /// automatically while the watcher runs.
  void noteLocalStart() {
    _localStartAt = DateTime.now();
    _scheduleFollowUps();
  }

  void _onAppStartedCharge() => noteLocalStart();

  /// The app asked a charger to stop [transactionId].
  ///
  /// [confirmedInApp] when the screen that did it already shows the outcome
  /// (the dashboard's receipt sheet). The sessions screen only says the
  /// request was accepted, so the finished pop-up is still news there.
  void noteLocalStop(int transactionId, {bool confirmedInApp = false}) {
    if (confirmedInApp) _localStops[transactionId] = DateTime.now();
    _scheduleFollowUps();
  }

  void _scheduleFollowUps() {
    if (_timer == null) return;
    _cancelFollowUps();
    for (final Duration delay in followUpDelays) {
      _followUps.add(Timer(delay, () => unawaited(checkNow())));
    }
  }

  void _cancelFollowUps() {
    for (final Timer timer in _followUps) {
      timer.cancel();
    }
    _followUps.clear();
  }

  /// Polls now. Overlapping calls share one request.
  Future<void> checkNow() {
    final String? userId = _userId;
    if (userId == null) return Future<void>.value();
    final Future<void>? running = _inFlight;
    if (running != null && _inFlightUser == userId) return running;
    _inFlightUser = userId;
    late final Future<void> poll;
    poll = _poll(userId).whenComplete(() {
      if (identical(_inFlight, poll)) _inFlight = null;
    });
    return _inFlight = poll;
  }

  String? _inFlightUser;

  Future<void> _poll(String userId) async {
    try {
      final List<ChargingSession> sessions = await _sessions.list(limit: pollLimit);
      if (_userId != userId) return;
      ingest(sessions);
    } catch (_) {
      // Offline or a transient failure — the next poll tries again.
    }
  }

  /// Diffs [sessions] (newest first, as the API lists them) against what is
  /// known. Public so a screen that already fetched the list — the dashboard
  /// re-syncs every 10 s while charging — can share it instead of the
  /// watcher waiting for its own poll.
  void ingest(List<ChargingSession> sessions) {
    if (_userId == null) return;
    final Map<int, SessionStatus>? known = _known;

    if (known == null) {
      _known = <int, SessionStatus>{
        for (final ChargingSession s in sessions) s.transactionId: s.status,
      };
      _baselineMaxId = sessions.fold<int>(
        0,
        (int max, ChargingSession s) => s.transactionId > max ? s.transactionId : max,
      );
      return;
    }

    final List<SessionEvent> events = <SessionEvent>[];
    // Oldest first, so two events from one poll arrive in the order they
    // happened.
    for (final ChargingSession session in sessions.reversed) {
      final int id = session.transactionId;
      final SessionStatus? previous = known[id];
      known[id] = session.status;

      if (previous == null) {
        if (id <= _baselineMaxId) continue;
        if (session.isActive) {
          events.add(_event(SessionEventType.started, session));
        } else if (session.status == SessionStatus.completed) {
          // Started and finished between two polls — a short charge, or the
          // whole of one while the app was in the background. The finish is
          // still news; the start is not any more.
          events.add(_event(SessionEventType.stopped, session));
        }
        continue;
      }

      if (previous == SessionStatus.active && !session.isActive) {
        events.add(_event(SessionEventType.stopped, session));
      }
    }

    final void Function(SessionEvent event)? onEvent = _onEvent;
    if (onEvent == null) return;
    for (final SessionEvent event in events) {
      onEvent(event);
    }
  }

  SessionEvent _event(SessionEventType type, ChargingSession session) {
    final DateTime now = DateTime.now();
    bool confirmed = false;
    if (type == SessionEventType.started) {
      final DateTime? at = _localStartAt;
      if (at != null && now.difference(at) <= localActionWindow) {
        confirmed = true;
        // One QR start accounts for one new session.
        _localStartAt = null;
      }
    } else {
      final DateTime? at = _localStops.remove(session.transactionId);
      confirmed = at != null && now.difference(at) <= localActionWindow;
    }
    return SessionEvent(type: type, session: session, confirmedInApp: confirmed);
  }

  @visibleForTesting
  String? get userId => _userId;
}
