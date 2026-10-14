import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final String? imageUrl;

  static Announcement? fromJson(Map<String, dynamic> json) {
    final String? id = json['id'] as String?;
    final String? title = json['title'] as String?;
    final String? body = json['body'] as String?;
    if (id == null || title == null || body == null) return null;
    return Announcement(id: id, title: title, body: body, imageUrl: json['imageUrl'] as String?);
  }
}

/// Operator-written Мэдээ — same backend the kiosk website's modal reads,
/// `/app-api/app/announcements`. Tracks which ones this device has already
/// dismissed, so the same announcement is not shown twice.
class AnnouncementService {
  AnnouncementService({ApiClient? client, FlutterSecureStorage? storage})
    : _client = client ?? ApiClient.shared,
      _storage = storage ?? const FlutterSecureStorage();

  static final AnnouncementService instance = AnnouncementService();

  static const String _seenKey = 'announcements_seen';

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  Future<List<Announcement>> fetchAll() async {
    final Map<String, dynamic> body = await _client.get('/app/announcements');
    return (body['announcements'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Announcement.fromJson)
        .whereType<Announcement>()
        .toList(growable: false);
  }

  /// The newest announcement this device has not dismissed yet, or null.
  Future<Announcement?> nextUnseen() async {
    final List<Announcement> all = await fetchAll();
    if (all.isEmpty) return null;
    final Set<String> seen = await _seenIds();
    for (final Announcement a in all) {
      if (!seen.contains(a.id)) return a;
    }
    return null;
  }

  Future<void> markSeen(String id) async {
    final Set<String> ids = await _seenIds();
    ids.add(id);
    // Keep the set from growing forever on an account with years of history.
    final List<String> capped = ids.length > 200 ? ids.skip(ids.length - 200).toList() : ids.toList();
    try {
      await _storage.write(key: _seenKey, value: capped.join(','));
    } catch (_) {
      // Private/locked keychain — the same announcement just shows again.
    }
  }

  Future<Set<String>> _seenIds() async {
    try {
      final String? raw = await _storage.read(key: _seenKey);
      if (raw == null || raw.isEmpty) return <String>{};
      return raw.split(',').toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
