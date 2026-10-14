import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum NotificationKind { wallet, announcement }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.imageUrl,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'at': at.toIso8601String(),
    'imageUrl': imageUrl,
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
      kind: json['kind'] == 'announcement' ? NotificationKind.announcement : NotificationKind.wallet,
      title: title,
      body: body,
      at: at,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// The driver's own notification history — wallet changes and announcements
/// — kept on-device so the bell icon has something to list after a toast or
/// a modal has already come and gone. Mirrors the kiosk website's store.
class NotificationsStore {
  NotificationsStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static final NotificationsStore instance = NotificationsStore();

  static const String _key = 'app_notifications';
  static const int _maxItems = 50;

  final FlutterSecureStorage _storage;

  final ValueNotifier<List<AppNotification>> items = ValueNotifier<List<AppNotification>>(
    <AppNotification>[],
  );
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final String? raw = await _storage.read(key: _key);
      if (raw == null) return;
      final dynamic parsed = jsonDecode(raw);
      if (parsed is! List) return;
      items.value = parsed
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .whereType<AppNotification>()
          .toList(growable: false);
    } catch (_) {
      // Corrupt or inaccessible storage — starts from an empty list.
    }
  }

  Future<void> _persist() async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(items.value.map((n) => n.toJson()).toList(growable: false)),
      );
    } catch (_) {
      // Nothing to persist; the in-memory list still works for this run.
    }
  }

  Future<void> add({
    required NotificationKind kind,
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    await _ensureLoaded();
    final notification = AppNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      title: title,
      body: body,
      at: DateTime.now(),
      imageUrl: imageUrl,
    );
    items.value = [notification, ...items.value].take(_maxItems).toList(growable: false);
    unread.value += 1;
    await _persist();
  }

  Future<void> markAllRead() async {
    await _ensureLoaded();
    unread.value = 0;
  }
}
