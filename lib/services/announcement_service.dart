import 'api_client.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? imageUrl;

  /// When the operator published it. Decides whether it is news to a driver
  /// or predates them.
  final DateTime? createdAt;

  static Announcement? fromJson(Map<String, dynamic> json) {
    final String? id = json['id'] as String?;
    final String? title = json['title'] as String?;
    final String? body = json['body'] as String?;
    if (id == null || title == null || body == null) return null;
    final String? image = json['imageUrl'] as String?;
    return Announcement(
      id: id,
      title: title,
      body: body,
      imageUrl: image == null || image.trim().isEmpty ? null : image,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Operator-written Мэдээ — same backend the kiosk website's modal reads,
/// `/app-api/app/announcements` (the last ten active ones, newest first).
///
/// Which of them a driver has already been shown is tracked per account by
/// `AnnouncementWatcherService`.
class AnnouncementService {
  AnnouncementService({ApiClient? client})
    : _client = client ?? ApiClient.shared;

  static final AnnouncementService instance = AnnouncementService();

  final ApiClient _client;

  Future<List<Announcement>> fetchAll() async {
    final Map<String, dynamic> body = await _client.get('/app/announcements');
    return (body['announcements'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Announcement.fromJson)
        .whereType<Announcement>()
        .toList(growable: false);
  }
}
