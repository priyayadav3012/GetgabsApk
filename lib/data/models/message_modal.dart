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

  // ✅ Voice Call Fields
  final int? callDurationSeconds;
  final String? callStatus;
  final String? callType;
final String? direction;
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

    // ✅ Voice Call
    int? callDurationSeconds,
    String? callStatus,
    String? callType,
    String? direction,
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

      // ✅ Voice Call
      callDurationSeconds:
          callDurationSeconds ?? this.callDurationSeconds,
      callStatus: callStatus ?? this.callStatus,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? 0,
      messageText: json['message_text'] ?? '',
      messageId: json['message_id'] ?? '',
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

      replyformsg: json['replyformsg'] ?? "",
       direction: json['direction'] ?? '',
      // ✅ Voice Call Data
      callDurationSeconds:
          json['call_duration_seconds'] ?? 0,

      callStatus:
          json['call_status'] ?? '',

      callType:
          json['message_sub_type'] ?? '',
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
    };
  }
}

List<Message> parseMessages(String jsonString) {
  final parsed = json.decode(jsonString).cast<Map<String, dynamic>>();
  return parsed.map<Message>((json) => Message.fromJson(json)).toList();
}