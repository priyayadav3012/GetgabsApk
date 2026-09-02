// Parses the FCM chat-message payload the backend sends via the `data2`
// field (a JSON-encoded string wrapping the raw message record). Shared
// between the foreground handler (NotificationService, main isolate) and
// the background handler (main.dart, runs in its own isolate spawned by the
// OS — can't share instance state with the main isolate) so both agree on
// the same detection/extraction logic.
import 'dart:convert';

/// True when this FCM payload represents a chat message. The backend
/// doesn't currently send an explicit `type: 'new_message'` field for these
/// (unlike call payloads, which do set `type`), so presence of `data2` is
/// used as the primary signal — `type == 'new_message'` still checked first
/// in case the backend adds it later.
bool isChatMessagePayload(Map<String, dynamic> data) {
  final type = data['type']?.toString() ?? '';
  return type == 'new_message' || data.containsKey('data2');
}

/// Decodes the nested `data2` JSON string down to the inner message record
/// (`data2` is `{"data": {...}}` as a string). Returns null if the shape
/// doesn't match rather than throwing, since this runs on payloads we don't
/// fully control the shape of.
Map<String, dynamic>? decodeChatPayload(Map<String, dynamic> data) {
  final raw = data['data2'];
  if (raw is! String) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final inner = decoded['data'];
      if (inner is Map<String, dynamic>) return inner;
    }
  } catch (_) {
    // fall through to null
  }
  return null;
}

/// A safe, human-readable preview of the message. `message_text` can itself
/// be a JSON-encoded WhatsApp API payload (e.g. for template/campaign sends,
/// or a customer's button/list reply) rather than plain text, so raw JSON is
/// never shown to the user — it's decoded down to the body text, or to the
/// picked button/list option title, matching how the chat screen renders
/// these same message types (messages_page.dart's fallback bubble branch).
String chatPreviewText(Map<String, dynamic>? chatData) {
  final raw = chatData?['message_text']?.toString().trim() ?? '';
  if (raw.isEmpty) return 'New message';
  if (!raw.startsWith('{') && !raw.startsWith('[')) return raw;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final interactive = decoded['interactive'];
      final replyTitle = interactive is Map
          ? (interactive['list_reply']?['title']?.toString() ??
              interactive['button_reply']?['title']?.toString() ??
              interactive['nfm_reply']?['name']?.toString())
          : null;
      final body = decoded['text']?['body']?.toString() ??
          decoded['body']?.toString() ??
          decoded['caption']?.toString() ??
          replyTitle;
      if (body != null && body.trim().isNotEmpty) return body.trim();
    }
  } catch (_) {
    // fall through to generic fallback below
  }
  return 'New message';
}

String chatSenderName(Map<String, dynamic>? chatData) {
  final name = chatData?['profile_name']?.toString().trim();
  return (name == null || name.isEmpty) ? 'New message' : name;
}
