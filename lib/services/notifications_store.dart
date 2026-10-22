import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

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
    this.dedupeKey,
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

  /// Identifies the event itself (e.g. a server notification id, or
  /// `session:1234:finished`), so the same event noticed twice — once by
  /// this device directly, once echoed back over the socket — is filed only
  /// once. Mirrors the kiosk website's store.
  final String? dedupeKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'at': at.toIso8601String(),
    'imageUrl': imageUrl,
    if (transactionId != null) 'transactionId': transactionId,
    if (dedupeKey != null) 'dedupeKey': dedupeKey,
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
      dedupeKey: json['dedupeKey'] as String?,
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

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;

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
      _disconnectSocket();
      return Future<void>.value();
    }
    _connectSocket(userId);
    return _loading = _load(userId);
  }

  /// Turns the server's wire name for a notification kind into the enum —
  /// mirrors the kiosk website's `NotificationKind` strings, which don't
  /// match this enum's Dart-cased `chargeStarted`/`chargeStopped` members.
  static NotificationKind _kindFromWire(String? wire) {
    switch (wire) {
      case 'announcement':
        return NotificationKind.announcement;
      case 'session-started':
        return NotificationKind.chargeStarted;
      case 'session-finished':
        return NotificationKind.chargeStopped;
      case 'wallet':
      default:
        return NotificationKind.wallet;
    }
  }

  /// Opens a socket so a notification filed while the app is open (another
  /// device topping up the wallet, an admin announcement, a charge another
  /// tag started) appears right away instead of waiting for the next time
  /// this list happens to reload. Reconnects on its own if the connection
  /// drops, as long as [userId] is still the signed-in driver.
  void _connectSocket(String userId) {
    _disconnectSocket();
    if (_userId != userId) return;

    final Uri base = Uri.parse(ApiConfig.baseUrl);
    final String scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final Uri wsUri = base.replace(
      scheme: scheme,
      path: '/ws/notifications',
      queryParameters: <String, String>{'userId': userId, 'role': 'driver'},
    );

    try {
      final WebSocketChannel channel = WebSocketChannel.connect(wsUri);
      _channel = channel;
      _socketSub = channel.stream.listen(
        (dynamic raw) {
          if (_userId != userId) return;
          try {
            final dynamic payload = jsonDecode(raw as String);
            if (payload is! Map<String, dynamic> || payload['type'] != 'notification') return;
            final dynamic data = payload['data'];
            if (data is! Map<String, dynamic>) return;
            final String? title = data['title'] as String?;
            final String? body = data['body'] as String?;
            if (title == null || body == null) return;
            final dynamic txId = data['transactionId'];
            final String? serverDedupe = data['dedupeKey'] as String? ??
                (data['id'] != null ? 'server:${data['id']}' : null);
            unawaited(
              add(
                kind: _kindFromWire(data['kind'] as String?),
                title: title,
                body: body,
                imageUrl: data['imageUrl'] as String?,
                transactionId: txId is num ? txId.toInt() : null,
                dedupeKey: serverDedupe,
              ),
            );
          } catch (_) {
            // Malformed payload — nothing to show for it.
          }
        },
        onDone: () => _scheduleReconnect(userId),
        onError: (Object _) => _scheduleReconnect(userId),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect(userId);
    }
  }

  void _scheduleReconnect(String userId) {
    _channel = null;
    _socketSub = null;
    if (_userId != userId) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () => _connectSocket(userId));
  }

  void _disconnectSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    _channel?.sink.close();
    _channel = null;
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
    String? dedupeKey,
  }) async {
    final String? userId = _userId;
    if (userId == null) return;
    await _loading;
    if (_userId != userId) return;
    if (dedupeKey != null && items.value.any((n) => n.dedupeKey == dedupeKey)) return;
    final DateTime now = DateTime.now();
    final notification = AppNotification(
      id: '${now.microsecondsSinceEpoch}-${_counter++}',
      kind: kind,
      title: title,
      body: body,
      at: now,
      imageUrl: imageUrl,
      transactionId: transactionId,
      dedupeKey: dedupeKey,
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
