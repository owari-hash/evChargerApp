import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/wallet.dart';
import 'wallet_service.dart';

/// Polls the signed-in driver's own wallet and reports the moment a new
/// ledger entry appears — a top-up settling, a charge being deducted, a
/// refund — so the app can pop a notification for it.
///
/// There is no driver-facing live event stream (only the CSMS console has
/// one), so this trades a little latency for not needing to build one —
/// same approach as the kiosk website's wallet watcher.
class WalletWatcherService {
  WalletWatcherService({WalletService? wallet, FlutterSecureStorage? storage})
    : _wallet = wallet ?? WalletService.instance,
      _storage = storage ?? const FlutterSecureStorage();

  static final WalletWatcherService instance = WalletWatcherService();

  /// Per account: a device-wide marker made the next driver to sign in on
  /// the same phone get a pop-up for their own latest entry on the first
  /// poll, because it never matched the previous driver's.
  static const String _legacyLastSeenKey = 'wallet_watcher_last_seen_entry';

  static String lastSeenKeyFor(String userId) => '$_legacyLastSeenKey:$userId';
  static const Duration _pollInterval = Duration(seconds: 20);

  final WalletService _wallet;
  final FlutterSecureStorage _storage;

  Timer? _timer;
  String? _userId;
  String? _lastSeenId;
  bool _primed = false;
  bool _legacyCleared = false;

  /// Bumped on every start and stop, so a poll still in flight from before
  /// cannot report into the next run — another driver's, say.
  int _run = 0;

  /// Starts polling [userId]'s wallet. Safe to call repeatedly — a second
  /// call for the same driver while already running is a no-op, so the app
  /// shell can just call this on every auth change.
  void start({required String userId, required void Function(WalletEntry entry) onNewEntry}) {
    if (_timer != null && _userId == userId) return;
    stop();
    _userId = userId;
    _lastSeenId = null;
    _primed = false;
    final int run = _run;
    unawaited(_poll(run, userId, onNewEntry));
    _timer = Timer.periodic(_pollInterval, (_) => _poll(run, userId, onNewEntry));
  }

  void stop() {
    _run++;
    _timer?.cancel();
    _timer = null;
  }

  /// One poll, for tests.
  @visibleForTesting
  Future<void> pollOnce({required String userId, required void Function(WalletEntry entry) onNewEntry}) {
    if (_userId != userId) {
      _userId = userId;
      _lastSeenId = null;
      _primed = false;
    }
    return _poll(_run, userId, onNewEntry);
  }

  Future<void> _poll(int run, String userId, void Function(WalletEntry entry) onNewEntry) async {
    try {
      if (!_legacyCleared) {
        _legacyCleared = true;
        await _storage.delete(key: _legacyLastSeenKey);
      }
      if (!_primed) {
        _lastSeenId = await _storage.read(key: lastSeenKeyFor(userId));
        _primed = true;
      }

      final WalletSnapshot snapshot = await _wallet.load(entryLimit: 1);
      if (run != _run || userId != _userId) return;
      final WalletEntry? latest = snapshot.entries.isNotEmpty ? snapshot.entries.first : null;
      if (latest == null) return;

      if (_lastSeenId == null) {
        // This driver's first poll on this device: record the baseline
        // silently so history from before never pops a notification.
        _lastSeenId = latest.id;
        await _storage.write(key: lastSeenKeyFor(userId), value: latest.id);
        return;
      }

      if (latest.id != _lastSeenId) {
        _lastSeenId = latest.id;
        await _storage.write(key: lastSeenKeyFor(userId), value: latest.id);
        onNewEntry(latest);
      }
    } catch (_) {
      // Offline or a transient failure — the next poll tries again.
    }
  }
}
