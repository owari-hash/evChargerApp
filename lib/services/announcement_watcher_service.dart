import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'announcement_service.dart';

/// Checks for new Мэдээ while the app is open — on start, on every resume and
/// every few minutes in the foreground — and reports the ones this driver has
/// not been shown yet.
///
/// Same shape as `SessionWatcherService`: there is no push channel, so it
/// polls `/app-api/app/announcements` and diffs against what is known. It
/// used to look only once, at cold start, so an announcement published while
/// a driver had the app open never reached them until they killed it.
///
/// What a driver has been shown is kept per account on the device. The first
/// time an account is seen here, announcements published before the account
/// was created (or, when the server does not say, before this first run) are
/// filed as seen silently: they are old news to a new driver. Anything newer
/// that is not yet seen is reported, and marked seen the moment it is — so
/// however the driver dismisses it, it never comes back.
class AnnouncementWatcherService {
  AnnouncementWatcherService({
    AnnouncementService? service,
    FlutterSecureStorage? storage,
    this.pollInterval = const Duration(minutes: 3),
    DateTime Function()? clock,
  }) : _service = service ?? AnnouncementService.instance,
       _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  /// Replaceable so tests can run the app frame against a stubbed feed.
  static AnnouncementWatcherService instance = AnnouncementWatcherService();

  /// The device-wide list from before this was kept per account.
  static const String legacySeenKey = 'announcements_seen';

  static String storageKeyFor(String userId) => '$legacySeenKey:$userId';

  /// Ids kept per account; the server only ever lists ten.
  static const int _maxIds = 200;

  final AnnouncementService _service;
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Duration pollInterval;

  Timer? _timer;
  String? _userId;
  DateTime? _accountCreatedAt;
  void Function(List<Announcement> fresh)? _onNew;
  Future<void>? _inFlight;
  String? _inFlightUser;

  /// Ids already handed to [_onNew], per account, for as long as the app
  /// runs. The keychain copy is the durable record, but a write to it can
  /// fail quietly; this keeps one dismissal from popping up again every poll.
  final Map<String, Set<String>> _reported = <String, Set<String>>{};

  bool get isRunning => _timer != null;

  @visibleForTesting
  String? get userId => _userId;

  /// Starts (or resumes) watching for [userId] and checks right away.
  ///
  /// [onNew] gets the unseen announcements, newest first.
  void start({
    required String userId,
    DateTime? accountCreatedAt,
    required void Function(List<Announcement> fresh) onNew,
  }) {
    _userId = userId;
    _accountCreatedAt = accountCreatedAt;
    _onNew = onNew;
    _timer ??= Timer.periodic(pollInterval, (_) => unawaited(checkNow()));
    unawaited(checkNow());
  }

  /// Pauses polling — the app went to the background.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Signed out: nothing more is reported for the previous driver.
  void signOut() {
    stop();
    _userId = null;
    _accountCreatedAt = null;
    _onNew = null;
  }

  /// Checks now. Overlapping calls for the same driver share one request.
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

  Future<void> _poll(String userId) async {
    final List<Announcement> all;
    try {
      all = await _service.fetchAll();
    } catch (_) {
      return; // Offline — the next check tries again.
    }
    if (_userId != userId) return;

    final _SeenState? state = await _read(userId);
    // The seen list is there but could not be read (a keychain error). Better
    // to show nothing this round than to replay everything as new.
    if (state == null) return;
    final DateTime cutoff = _accountCreatedAt ?? state.since;
    final Set<String> reported = _reported.putIfAbsent(
      userId,
      () => <String>{},
    );

    final List<Announcement> fresh = <Announcement>[];
    bool changed = state.isNew;
    for (final Announcement a in all) {
      if (state.ids.contains(a.id)) continue;
      if (reported.contains(a.id)) {
        // Shown already this run but the keychain lost it; file it again.
        state.ids.add(a.id);
        changed = true;
        continue;
      }
      state.ids.add(a.id);
      changed = true;
      final DateTime? at = a.createdAt;
      if (at != null && at.isBefore(cutoff)) continue; // silent baseline
      fresh.add(a);
    }
    if (changed) await _write(userId, state);
    if (_userId != userId || fresh.isEmpty) return;
    reported.addAll(fresh.map((Announcement a) => a.id));
    _onNew?.call(fresh);
  }

  /// Null when the keychain itself fails — distinct from "nothing saved yet".
  Future<_SeenState?> _read(String userId) async {
    final String? raw;
    try {
      raw = await _storage.read(key: storageKeyFor(userId));
    } catch (error) {
      debugPrint('announcements: could not read seen list: $error');
      return null;
    }
    try {
      if (raw != null && raw.isNotEmpty) {
        final dynamic json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          final DateTime? since = DateTime.tryParse('${json['since']}');
          final List<dynamic> ids = json['ids'] is List
              ? json['ids'] as List<dynamic>
              : const <dynamic>[];
          return _SeenState(
            ids: ids.map((dynamic id) => '$id').toList(),
            since: since ?? _clock(),
            isNew: since == null,
          );
        }
      }
    } catch (_) {
      // Unreadable — start this account over.
    }
    // First run for this account on this device. Whatever was dismissed
    // here before the list was kept per account counts as seen, so an
    // update does not replay it.
    final List<String> legacy = <String>[];
    try {
      final String? raw = await _storage.read(key: legacySeenKey);
      if (raw != null && raw.isNotEmpty) legacy.addAll(raw.split(','));
    } catch (_) {}
    return _SeenState(ids: legacy, since: _clock(), isNew: true);
  }

  Future<void> _write(String userId, _SeenState state) async {
    final List<String> ids = state.ids.length > _maxIds
        ? state.ids.sublist(state.ids.length - _maxIds)
        : state.ids;
    try {
      await _storage.write(
        key: storageKeyFor(userId),
        value: jsonEncode(<String, dynamic>{
          'since': state.since.toIso8601String(),
          'ids': ids,
        }),
      );
    } catch (error) {
      // A locked keychain: the in-memory list still stops a repeat this run.
      debugPrint('announcements: could not save seen list: $error');
    }
  }
}

class _SeenState {
  _SeenState({required this.ids, required this.since, required this.isNew});

  final List<String> ids;
  final DateTime since;
  final bool isNew;
}
