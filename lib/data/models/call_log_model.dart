import 'active_chat_model.dart';

// Parses the /voiceCallLogs response shape:
// { id, call_id, direction, call_status, call_started_at,
//   call_connected_at, call_duration_seconds, is_seen,
//   customer_wa_number, voice_call_respones: { profile_wa_key,
//   get_customer_from_customer_list: { profile_name } } }
class CallLogEntry {
  final String customerName;
  final String phoneNumber;
  final bool isOutgoing;
  final bool isMissed;
  final int callDurationSeconds;
  final DateTime callTime;
  final bool isSeen;
  // Built from the same customer fields MessagesPage already expects
  // (profile_wa_id/profile_wa_key/profile_name) — lets a call-log row
  // open that customer's chat directly. Null if the customer couldn't
  // be resolved from the response.
  final Profile? profile;

  CallLogEntry({
    required this.customerName,
    required this.phoneNumber,
    required this.isOutgoing,
    required this.isMissed,
    required this.callDurationSeconds,
    required this.callTime,
    this.isSeen = true,
    this.profile,
  });

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    final voiceCallResponse =
        json['voice_call_respones'] as Map<String, dynamic>?;
    final customer = voiceCallResponse?['get_customer_from_customer_list']
        as Map<String, dynamic>?;
    final profileSource = customer ?? voiceCallResponse;

    final phoneNumber = json['customer_wa_number']?.toString() ?? '';
    final connectedAt = json['call_connected_at'];

    return CallLogEntry(
      customerName: customer?['profile_name']?.toString() ?? '',
      phoneNumber: phoneNumber,
      isOutgoing: (json['direction']?.toString().toLowerCase() ?? '')
          .contains('outbound'),
      isMissed: connectedAt == null || connectedAt.toString().isEmpty,
      callDurationSeconds:
          int.tryParse(json['call_duration_seconds']?.toString() ?? '') ?? 0,
      callTime: DateTime.tryParse(json['call_started_at']?.toString() ?? '') ??
          DateTime.now(),
      isSeen: json['is_seen'] == 1 || json['is_seen'] == true,
      profile: profileSource != null ? Profile.fromJson(profileSource) : null,
    );
  }
}
