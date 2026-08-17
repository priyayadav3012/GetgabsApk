import 'dart:convert';

class Message {
  final int id;
  final String messageText;
  final String messageId;
  final String messageType;
  final bool isAutoreply;
  final String? captionText;
  final String? templateData;
  final String? mediaType;
  final int sender;
  final bool seenByAdmin;
  final bool markMsgAsRead;
  final bool seenByUser;
  final String? deliveryStatus;
  final int? subuserSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool local;
  final String? replyformsg;

  // ✅ Voice Call Fields (parsed out of the nested `callHistory` JSON string
  // the API sends alongside message_type == 'interactive' call-related
  // messages, for BOTH call directions — see Message.fromJson)
  final int? callDurationSeconds;
  final String? callStatus;
  final String? callType;
  final String? direction;
  final String? callConnectedAt;
  final bool hasCallHistory;

  // ✅ Note Fields (Assign/Co-Assign/Team-Assign responses — message_type == 'note')
  final String? noteCreatedBy;
  final String? noteType;

  // ✅ Reaction — WhatsApp reactions arrive as their own message_type ==
  // 'reaction' entry (see groupMessagesByDate), which is stripped out of the
  // displayed list and folded into this field on the message it targets, so
  // it renders as a small emoji badge on that message instead of its own bubble.
  final String? reactionEmoji;

  Message({
    required this.id,
    required this.messageText,
    required this.messageId,
    required this.messageType,
    required this.isAutoreply,
    this.captionText,
    this.templateData,
    this.mediaType,
    required this.sender,
    required this.seenByAdmin,
    required this.markMsgAsRead,
    required this.seenByUser,
    this.deliveryStatus,
    this.subuserSenderId,
    required this.createdAt,
    required this.updatedAt,
    this.local = false,
    required this.replyformsg,

    // ✅ Voice Call
    this.callDurationSeconds,
    this.callStatus,
    this.callType,
    this.direction,
    this.callConnectedAt,
    this.hasCallHistory = false,

    // ✅ Note
    this.noteCreatedBy,
    this.noteType,

    // ✅ Reaction
    this.reactionEmoji,
  });

  bool get isSentByMe => sender != 1;

  String get displayText {
  if (messageType != 'text') return messageText;
  try {
    final decoded = jsonDecode(messageText);
    final body = decoded['text']?['body']?.toString();
    if (body != null && body.isNotEmpty) return body;
  } catch (_) {}
  return messageText;
}

  // A short, human-readable one-liner for THIS message regardless of its
  // wire format — used for reply-quote previews (the "Replying to" bar,
  // and the quoted box inside a sent reply) so no message type ever shows
  // raw JSON there. displayText only unwraps the 'text' case; this covers
  // every type buildMessageWidget knows how to render.
  String get previewText {
    try {
      switch (messageType) {
        case 'text':
          final decoded = jsonDecode(messageText);
          final body = decoded['text']?['body']?.toString();
          return (body != null && body.isNotEmpty) ? body : messageText;
        case 'reply_msg':
          final decoded = jsonDecode(messageText);
          return decoded['msgcontent']?.toString() ??
              decoded['text']?['body']?.toString() ??
              'Reply';
        case 'template':
          // A quoted template preview is just the generic label, always —
          // no attempt to extract real body text (a real WhatsApp
          // template's body is spread across messageText/templateData in
          // several possible shapes, extracting it reliably in a one-line
          // preview isn't worth the fragility it introduced).
          return '📄 Template';
        case 'interactive':
        case 'buttons':
          final decoded = jsonDecode(messageText);
          final direct = decoded['text']?['body']?.toString() ??
              decoded['interactive']?['body']?['text']?.toString() ??
              decoded['body']?['text']?.toString();
          return (direct != null && direct.isNotEmpty)
              ? direct
              : (captionText?.isNotEmpty ?? false ? captionText! : messageType);
        case 'image':
          return '📷 Photo';
        case 'video':
          return '🎥 Video';
        case 'audio':
          return '🎤 Audio';
        case 'document':
          return '📄 Document';
        case 'location':
          return '📍 Location';
        case 'contacts':
          return '👤 Contact';
        default:
          return messageText;
      }
    } catch (_) {
      // Failed to parse as JSON — either genuinely plain text (fine, show
      // as-is) or malformed JSON for a structured type (show the type
      // label instead of dumping raw braces on screen).
      return messageText.trimLeft().startsWith('{') ? messageType : messageText;
    }
  }

  Message copyWith({
    int? id,
    String? messageText,
    String? messageId,
    String? messageType,
    bool? isAutoreply,
    int? sender,
    String? templateData,
    String? captionText,
    bool? seenByAdmin,
    bool? markMsgAsRead,
    bool? seenByUser,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? local,
    String? deliveryStatus,
    String? replyformsg,
    int? subuserSenderId,

    // ✅ Voice Call
    int? callDurationSeconds,
    String? callStatus,
    String? callType,
    String? direction,
    String? callConnectedAt,
    bool? hasCallHistory,

    // ✅ Note
    String? noteCreatedBy,
    String? noteType,

    // ✅ Reaction
    String? reactionEmoji,
  }) {
    return Message(
      id: id ?? this.id,
      messageText: messageText ?? this.messageText,
      messageId: messageId ?? this.messageId,
      messageType: messageType ?? this.messageType,
      isAutoreply: isAutoreply ?? this.isAutoreply,
      sender: sender ?? this.sender,
      captionText: captionText ?? this.captionText,
      seenByAdmin: seenByAdmin ?? this.seenByAdmin,
      markMsgAsRead: markMsgAsRead ?? this.markMsgAsRead,
      seenByUser: seenByUser ?? this.seenByUser,
      createdAt: createdAt ?? this.createdAt,
      templateData: templateData ?? this.templateData,
      updatedAt: updatedAt ?? this.updatedAt,
      local: local ?? this.local,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      replyformsg: replyformsg ?? this.replyformsg,
      subuserSenderId: subuserSenderId ?? this.subuserSenderId,

      // ✅ Voice Call
      callDurationSeconds:
          callDurationSeconds ?? this.callDurationSeconds,
      callStatus: callStatus ?? this.callStatus,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      callConnectedAt: callConnectedAt ?? this.callConnectedAt,
      hasCallHistory: hasCallHistory ?? this.hasCallHistory,
      noteCreatedBy: noteCreatedBy ?? this.noteCreatedBy,
      noteType: noteType ?? this.noteType,
      reactionEmoji: reactionEmoji ?? this.reactionEmoji,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    // `callHistory` arrives as a JSON-encoded string (or the literal string
    // "null") alongside message_type == 'interactive' call-related messages —
    // it holds the actual call_status/call_duration_seconds/direction data
    // for BOTH call directions (USER_INITIATED = incoming, BUSINESS_INITIATED
    // = outgoing); those are NOT top-level fields on the message itself.
    Map<String, dynamic>? callHistory;
    final rawCallHistory = json['callHistory'];
    if (rawCallHistory is String &&
        rawCallHistory.isNotEmpty &&
        rawCallHistory != 'null') {
      try {
        final decoded = jsonDecode(rawCallHistory);
        if (decoded is Map<String, dynamic>) callHistory = decoded;
      } catch (_) {}
    } else if (rawCallHistory is Map) {
      callHistory = Map<String, dynamic>.from(rawCallHistory);
    }

    // replyformsg (the quoted-message snapshot ReplyMessageUi renders) is
    // only ever populated locally, right when WE compose a reply (see
    // MessagesPageController.sendMessage) — a reload from the server never
    // sends that field back. The server instead sends a `reply_to` block
    // with the original message's own content, so a reply_msg message
    // still shows its quoted preview after leaving and reopening the chat.
    // `content` there is already a clean human-readable string (not raw
    // WhatsApp JSON), so it's synthesized here as a plain "text" snapshot —
    // ReplyMessageUi's 'text' case shows a non-JSON string as-is.
    String replyformsgValue = json['replyformsg'] ?? "";
    final replyTo = json['reply_to'];
    if (replyformsgValue.isEmpty && replyTo is Map) {
      replyformsgValue = jsonEncode({
        'message_id': replyTo['message_id']?.toString() ?? '',
        'message_type': 'text',
        'message_text': replyTo['content']?.toString() ?? '',
        'template_data': null,
        'local': false,
      });
    }

    return Message(
      id: json['id'] ?? 0,
      // Regular messages use 'message_text'; the Assign/Co-Assign/Team-Assign
      // "note" API responses (see postman/assign_chat_apis.postman_collection.json)
      // use 'content' instead — fall back to it so a note object can be fed
      // straight into Message.fromJson without a separate adapter.
      messageText: json['message_text'] ?? json['content'] ?? '',
      messageId: json['message_id']?.toString() ??
          (json['id'] != null ? 'note_${json['id']}' : ''),
      messageType: json['message_type'] ?? '',
      isAutoreply: (json['is_autoreply'] ?? "no") == "yes",
      captionText: json['caption_text'] ?? '',
      templateData: json['template_data'] ?? '',
      mediaType: json['media_type'] ?? '',
      sender: json['sender'] ?? 0,
      seenByAdmin: (json['seenbyadmin'] ?? 0) == 1,
      markMsgAsRead: (json['mark_msg_as_read'] ?? "no") == "yes",
      seenByUser: (json['seenbyuser'] ?? 0) == 1,
      deliveryStatus: json['delivery_status'] ?? 'pending',
      subuserSenderId: json['subuser_sender_id'] ?? -1,
      createdAt:
          DateTime.parse(
            json['created_at'] ??
                DateTime.now().toIso8601String(),
          ).add(const Duration(hours: 5, minutes: 30)),

      updatedAt: DateTime.parse(
        json['updated_at'] ??
            DateTime.now().toIso8601String(),
      ),

      replyformsg: replyformsgValue,

      // ✅ Voice Call Data — from the nested callHistory JSON, not top-level
      // keys. Works identically regardless of call direction (incoming or
      // outgoing) since callHistory carries a `direction` field itself.
      direction: callHistory?['direction']?.toString() ?? '',
      callDurationSeconds: callHistory?['call_duration_seconds'] ?? 0,
      callStatus: callHistory?['call_status']?.toString() ?? '',
      callConnectedAt: callHistory?['call_connected_at']?.toString(),
      hasCallHistory: callHistory != null,

      // ✅ Note Data
      noteCreatedBy: json['note_created_by'] ?? '',
      noteType: json['note_type'] ?? '',

      callType: json['message_sub_type'] ?? '',
    );
  }

  get senderName => null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_text': messageText,
      'message_id': messageId,
      'message_type': messageType,
      'is_autoreply': isAutoreply ? "yes" : "no",
      'caption_text': captionText,
      'template_data': templateData,
      'media_type': mediaType,
      'sender': sender,
      'seenbyadmin': seenByAdmin ? 1 : 0,
      'mark_msg_as_read': markMsgAsRead ? "yes" : "no",
      'seenbyuser': seenByUser ? 1 : 0,
      'delivery_status': deliveryStatus,
      'subuser_sender_id': subuserSenderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'local': local,
      'replyformsg': replyformsg,

      // ✅ Voice Call
      'call_duration_seconds': callDurationSeconds,
      'call_status': callStatus,
      'message_sub_type': callType,

      // ✅ Note
      'note_created_by': noteCreatedBy,
      'note_type': noteType,
    };
  }
}

List<Message> parseMessages(String jsonString) {
  final parsed = json.decode(jsonString).cast<Map<String, dynamic>>();
  return parsed.map<Message>((json) => Message.fromJson(json)).toList();
}