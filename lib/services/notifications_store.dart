import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [chargeStarted] and [chargeStopped] come from the session watcher: a
/// charge on the driver's own tag beginning or ending, wherever it was
/// started from.
enum NotificationKind { wallet, announcement, chargeStarted, chargeStopped }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.imageUrl,
    this.transactionId,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;
  final String? imageUrl;

  /// The charging session a [NotificationKind.chargeStarted] or
  /// [NotificationKind.chargeStopped] entry is about.
  final int? transactionId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'at': at.toIso8601String(),
    'imageUrl': imageUrl,
    if (transactionId != null) 'transactionId': transactionId,
  };

  static AppNotification? fromJson(Map<String, dynamic> json) {
    final String? id = json['id'] as String?;
    final String? title = json['title'] as String?;
    final String? body = json['body'] as String?;
    final String? atRaw = json['at'] as String?;
    if (id == null || title == null || body == null || atRaw == null) return null;
    final DateTime? at = DateTime.tryParse(atRaw);
    if (at == null) return null;
    return AppNotification(
      id: id,
      kind: NotificationKind.values.firstWhere(
        (NotificationKind k) => k.name == json['kind'],
        orElse: () => NotificationKind.wallet,
      ),
      title: title,
      body: body,
      at: at,
      imageUrl: json['imageUrl'] as String?,
      transactionId: json['transactionId'] is num ? (json['transactionId'] as num).toInt() : null,
    );
  }
}

/// The driver's own notification history — wallet changes, announcements and
/// charges starting or finishing — kept on-device so the bell icon has
/// something to list after a toast or a modal has already come and gone.
/// Mirrors the kiosk website's store.
///
/// Kept per account: the history is stored under the signed-in driver's id,
/// and [setUser] swaps it out on every sign-in and sign-out, so whoever signs
/// in next on the same phone never sees the previous driver's charges and
/// payments.
class NotificationsStore {
  NotificationsStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static final NotificationsStore instance = NotificationsStore();

  /// The one device-wide list from before the history was per account. It
  /// cannot be attributed to anyone, so it is deleted rather than migrated.
  static const String _legacyKey = 'app_notifications';
  static const int _maxItems = 50;

  static String storageKeyFor(String userId) => '$_legacyKey:$userId';

  final FlutterSecureStorage _storage;

  final ValueNotifier<List<AppNotification>> items = ValueNotifier<List<AppNotification>>(
    <AppNotification>[],
  );
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  String? _userId;
  Future<void>? _loading;
  bool _legacyCleared = false;
  int _counter = 0;

  /// The account whose history is showing, or null when signed out.
  String? get userId => _userId;

  /// Switches to [userId]'s history — null on sign-out, which empties the
  /// list and the unread badge. A no-op when it is already that account.
  Future<void> setUser(String? userId) {
    if (userId == _userId && (_loading != null || userId == null)) {
      return _loading ?? Future<void>.value();
    }
    _userId = userId;
    items.value = const <AppNotification>[];
    unread.value = 0;
    if (!_legacyCleared) {
      _legacyCleared = true;
      _storage.delete(key: _legacyKey).catchError((Object _) {});
    }
    if (userId == null) {
      _loading = null;
      return Future<void>.value();
    }
    return _loading = _load(userId);
  }

  Future<void> _load(String userId) async {
    try {
      final String? raw = await _storage.read(key: storageKeyFor(userId));
      // Signed out, or someone else signed in, while this was being read.
      if (raw == null || _userId != userId) return;
      final dynamic parsed = jsonDecode(raw);
      if (parsed is! List) return;
      final List<AppNotification> stored = parsed
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .whereType<AppNotification>()
          .toList(growable: false);
      // Anything added while the read was in flight goes on top.
      items.value = <AppNotification>[...items.value, ...stored].take(_maxItems).toList(growable: false);
    } catch (_) {
      // Corrupt or inaccessible storage — starts from an empty list.
    }
  }

  Future<void> _persist(String userId) async {
    try {
      await _storage.write(
        key: storageKeyFor(userId),
        value: jsonEncode(items.value.map((n) => n.toJson()).toList(growable: false)),
      );
    } catch (_) {
      // Nothing to persist; the in-memory list still works for this run.
    }
  }

  /// Files a notification under the signed-in driver. Dropped when nobody is
  /// signed in: there is no account to keep it for.
  Future<void> add({
    required NotificationKind kind,
    required String title,
    required String body,
    String? imageUrl,
    int? transactionId,
  }) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _loading;
    if (_userId != userId) return;
    final DateTime now = DateTime.now();
    final notification = AppNotification(
      id: '${now.microsecondsSinceEpoch}-${_counter++}',
      kind: kind,
      title: title,
      body: body,
      at: now,
      imageUrl: imageUrl,
      transactionId: transactionId,
    );
    items.value = [notification, ...items.value].take(_maxItems).toList(growable: false);
    unread.value += 1;
    await _persist(userId);
  }

  Future<void> markAllRead() async {
    await _loading;
    unread.value = 0;
  }
}
