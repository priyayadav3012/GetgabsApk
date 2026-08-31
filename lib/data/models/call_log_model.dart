import 'package:getgabs/domain/end_points/api_end_points.dart';

import 'active_chat_model.dart';

// Parses the /voiceCallLogs response shape:
// { id, call_id, direction, call_status, call_started_at,
//   call_connected_at, call_duration_seconds, is_seen,
//   customer_wa_number, recording_status, recording_wasabi_path,
//   transcript_status, transcript_wasabi_path, voice_call_respones:
//   { profile_wa_key, get_customer_from_customer_list: { profile_name } } }
class CallLogEntry {
  // Uniquely identifies this call log row — lets the controller remember
  // which missed calls the user has already viewed (the tab's badge should
  // only count ones they haven't) across pagination and refreshes.
  final String id;
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

  final String? recordingStatus;
  final String? recordingUrl;
  final String? transcriptStatus;
  final String? transcriptUrl;

  CallLogEntry({
    required this.id,
    required this.customerName,
    required this.phoneNumber,
    required this.isOutgoing,
    required this.isMissed,
    required this.callDurationSeconds,
    required this.callTime,
    this.isSeen = true,
    this.profile,
    this.recordingStatus,
    this.recordingUrl,
    this.transcriptStatus,
    this.transcriptUrl,
  });

  // Gated on the URL actually being present rather than an exact
  // recording_status/transcript_status string match — the backend's status
  // wording isn't guaranteed to always be 'stored' for every recorded call,
  // and a present wasabi_path is the stronger signal that a file exists.
  bool get hasRecording => recordingUrl != null;
  bool get hasTranscript => transcriptUrl != null;

  static String? _mediaUrl(dynamic wasabiPath) {
    final path = wasabiPath?.toString();
    if (path == null || path.isEmpty) return null;
    return '${ApiEndPoints.mediaStorageBaseUrl}$path';
  }

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    final voiceCallResponse =
        json['voice_call_respones'] as Map<String, dynamic>?;
    final customer = voiceCallResponse?['get_customer_from_customer_list']
        as Map<String, dynamic>?;
    final profileSource = customer ?? voiceCallResponse;

    final phoneNumber = json['customer_wa_number']?.toString() ?? '';
    final connectedAt = json['call_connected_at'];

    return CallLogEntry(
      id: json['id']?.toString() ?? json['call_id']?.toString() ?? '',
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
      recordingStatus: json['recording_status']?.toString(),
      recordingUrl: _mediaUrl(json['recording_wasabi_path']),
      transcriptStatus: json['transcript_status']?.toString(),
      transcriptUrl: _mediaUrl(json['transcript_wasabi_path']),
    );
  }
}

// One speaker turn from the transcript JSON's `transcript.segments` array:
// { id, speaker: "Business"|"Customer", channel, start, end, text,
//   confidence, words: [...] }. `words` (per-word timing) isn't used here.
class TranscriptSegment {
  final String speaker;
  final double start;
  final double end;
  final String text;

  TranscriptSegment({
    required this.speaker,
    required this.start,
    required this.end,
    required this.text,
  });

  bool get isBusiness => speaker.toLowerCase() == 'business';

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      speaker: json['speaker']?.toString() ?? '',
      start: (json['start'] as num?)?.toDouble() ?? 0,
      end: (json['end'] as num?)?.toDouble() ?? 0,
      text: json['text']?.toString() ?? '',
    );
  }
}

// Parses the call-transcript JSON shape:
// { metadata: { processed_at, audio: {...} },
//   transcript: { text, language, duration, confidence, segments: [...] } }
class CallTranscript {
  final String language;
  final double durationSeconds;
  final double confidence;
  final List<TranscriptSegment> segments;
  // Flat, single-string version of the same transcript (speaker tags inline,
  // e.g. "[Business] Hello. [Customer] ..."). Kept only as a copy-to-
  // clipboard fallback when segments somehow come back empty.
  final String rawText;

  CallTranscript({
    required this.language,
    required this.durationSeconds,
    required this.confidence,
    required this.segments,
    required this.rawText,
  });

  bool get isEmpty => segments.isEmpty && rawText.trim().isEmpty;

  factory CallTranscript.empty() => CallTranscript(
        language: '',
        durationSeconds: 0,
        confidence: 0,
        segments: const [],
        rawText: '',
      );

  factory CallTranscript.fromJson(Map<String, dynamic> json) {
    final transcript = json['transcript'] as Map<String, dynamic>? ?? {};
    final segmentsJson = transcript['segments'] as List? ?? [];
    return CallTranscript(
      language: transcript['language']?.toString() ?? '',
      durationSeconds: (transcript['duration'] as num?)?.toDouble() ?? 0,
      confidence: (transcript['confidence'] as num?)?.toDouble() ?? 0,
      segments: segmentsJson
          .whereType<Map<String, dynamic>>()
          .map(TranscriptSegment.fromJson)
          .toList(),
      rawText: transcript['text']?.toString() ?? '',
    );
  }
}
