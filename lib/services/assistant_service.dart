import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_client.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  ChatMessage copyWithContent(String content) => ChatMessage(role: role, content: content);

  Map<String, dynamic> toJson() => {
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'content': content,
  };

  static ChatMessage? fromJson(Map<String, dynamic> json) {
    final String? content = json['content'] as String?;
    if (content == null) return null;
    return ChatMessage(
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
      content: content,
    );
  }
}

/// Talks to the same `/app-api/assistant` the kiosk website's chat widget
/// uses — one backend, one conversation contract, for both front ends.
class AssistantService {
  AssistantService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static final AssistantService instance = AssistantService();

  final http.Client _http;

  /// Streams the assistant's reply for [history] (the full conversation so
  /// far, including the new question as its last message) through [onChunk],
  /// one piece of text at a time as it arrives.
  ///
  /// Throws [ApiException] on a failure the server reported before any text
  /// came back; a failure mid-stream is appended to the reply as plain text
  /// by the server itself, the same way the kiosk widget sees it.
  Future<void> ask(
    List<ChatMessage> history, {
    required String page,
    required void Function(String chunk) onChunk,
  }) async {
    final request = http.Request('POST', ApiConfig.uri('/assistant'))
      ..headers.addAll(await ApiClient.shared.streamHeaders())
      ..body = jsonEncode({
        'messages': history.map((m) => m.toJson()).toList(growable: false),
        'page': page,
      });

    final http.StreamedResponse response = await _http.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String body = await response.stream.bytesToString();
      String message = 'Туслахтай холбогдож чадсангүй.';
      try {
        final dynamic parsed = jsonDecode(body);
        if (parsed is Map && parsed['error'] is String) message = parsed['error'] as String;
      } catch (_) {
        // Non-JSON error body; the fallback message stands.
      }
      throw ApiException(statusCode: response.statusCode, message: message);
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      if (chunk.isNotEmpty) onChunk(chunk);
    }
  }
}
