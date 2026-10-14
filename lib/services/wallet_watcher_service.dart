import 'dart:async';

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

  static const String _lastSeenKey = 'wallet_watcher_last_seen_entry';
  static const Duration _pollInterval = Duration(seconds: 20);

  final WalletService _wallet;
  final FlutterSecureStorage _storage;

  Timer? _timer;
  String? _lastSeenId;
  bool _primed = false;

  /// Starts polling. Safe to call repeatedly — a second call while already
  /// running is a no-op, so the app shell can just call this in `initState`.
  void start({required void Function(WalletEntry entry) onNewEntry}) {
    if (_timer != null) return;
    _lastSeenId = null;
    _primed = false;
    unawaited(_poll(onNewEntry));
    _timer = Timer.periodic(_pollInterval, (_) => _poll(onNewEntry));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll(void Function(WalletEntry entry) onNewEntry) async {
    try {
      if (!_primed) {
        _lastSeenId = await _storage.read(key: _lastSeenKey);
        _primed = true;
      }

      final WalletSnapshot snapshot = await _wallet.load(entryLimit: 1);
      final WalletEntry? latest = snapshot.entries.isNotEmpty ? snapshot.entries.first : null;
      if (latest == null) return;

      if (_lastSeenId == null) {
        // First poll this run: record the baseline silently so history from
        // before the app opened never pops a notification.
        _lastSeenId = latest.id;
        await _storage.write(key: _lastSeenKey, value: latest.id);
        return;
      }

      if (latest.id != _lastSeenId) {
        _lastSeenId = latest.id;
        await _storage.write(key: _lastSeenKey, value: latest.id);
        onNewEntry(latest);
      }
    } catch (_) {
      // Offline or a transient failure — the next poll tries again.
    }
  }
}
