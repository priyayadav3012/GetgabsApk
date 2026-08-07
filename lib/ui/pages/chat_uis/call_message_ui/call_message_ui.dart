import 'package:flutter/material.dart';

import '../base_message_ui.dart';

// WhatsApp-style call-log card — covers BOTH directions:
//   - USER_INITIATED  = the customer called the business  -> incoming
//   - BUSINESS_INITIATED = the business called the customer -> outgoing
// and both outcomes (connected vs. never-connected/missed), for each direction.
class CallMessageUi extends StatelessWidget {
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;
  final int? callDurationSeconds;
  final String? callStatus;
  final String? direction;
  final String? callConnectedAt;

  const CallMessageUi({
    super.key,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
    this.callDurationSeconds,
    this.callStatus,
    this.direction,
    this.callConnectedAt,
  });

  // A call that never connected (no call_connected_at timestamp) is the most
  // reliable "missed/unanswered" signal — call_status label wording varies
  // (e.g. "call_terminated" with 0 duration is also effectively missed).
  bool get _isMissed {
    if (callConnectedAt != null && callConnectedAt!.isNotEmpty) return false;
    final status = (callStatus ?? '').toLowerCase();
    if (status.contains('answer') || status.contains('connect')) return false;
    return true;
  }

  // WhatsApp Calling API direction values are BUSINESS_INITIATED /
  // USER_INITIATED (from the customer's perspective) — a business-initiated
  // call is outgoing (we called the customer); anything else (including
  // USER_INITIATED or an unrecognized/empty value) is treated as incoming
  // (the customer called us) — the more common case for this app.
  bool get _isOutgoing =>
      (direction ?? '').toLowerCase().contains('business');

  String get _formattedDuration {
    final seconds = callDurationSeconds ?? 0;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds == 0
        ? '${minutes}m'
        : '${minutes}m ${remainingSeconds}s';
  }

  String get _title {
    if (_isMissed) {
      return _isOutgoing ? 'Unanswered Call' : 'Missed Voice Call';
    }
    return 'Voice Call';
  }

  String get _subtitle {
    if (_isMissed) return _isOutgoing ? 'No answer' : 'Missed';
    return _formattedDuration;
  }

  @override
  Widget build(BuildContext context) {
    final missed = _isMissed;
    final accentColor = missed ? Colors.red : Colors.green.shade600;

    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.12),
            ),
            child: Icon(
              missed
                  ? (_isOutgoing
                      ? Icons.call_missed_outgoing
                      : Icons.call_missed)
                  : Icons.call,
              size: 18,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: missed ? Colors.red : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
