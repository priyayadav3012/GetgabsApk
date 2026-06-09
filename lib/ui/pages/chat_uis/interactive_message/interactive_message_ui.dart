import 'dart:convert';
import 'package:flutter/material.dart';
import '../base_message_ui.dart';

class InteractiveMessageUi extends StatelessWidget {
  final String messageText;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;

  const InteractiveMessageUi({
    super.key,
    required this.messageText,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
  });

  @override
  Widget build(BuildContext context) {
    String displayText = 'Unsupported message format';

    try {
      final messageJson = jsonDecode(messageText);

      final interactive = messageJson['interactive'];

      if (interactive != null) {

        /// =========================================
        /// NFM Reply
        /// =========================================
        if (interactive['nfm_reply'] != null) {

          final nfmReply = interactive['nfm_reply'];

          if (nfmReply['response_json'] != null) {

            final responseJson =
                jsonDecode(nfmReply['response_json']);

            displayText =
                _formatInteractiveResponse(responseJson);
          }
        }

        /// =========================================
        /// Button Reply
        /// =========================================
        else if (interactive['button_reply'] != null) {

          final buttonReply =
              interactive['button_reply'];

          displayText =
              buttonReply['title'] ??
              buttonReply['id'] ??
              'Button clicked';
        }

        /// =========================================
        /// List Reply
        /// =========================================
        else if (interactive['list_reply'] != null) {

          final listReply =
              interactive['list_reply'];

          displayText =
              listReply['title'] ??
              listReply['description'] ??
              'List item selected';
        }

        /// =========================================
        /// Call Permission Reply
        /// =========================================
        /// =========================================
/// Call Permission Reply
/// =========================================
else if (interactive['call_permission_reply'] != null) {

  final callReply =
      interactive['call_permission_reply'];
 debugPrint('xccscall_permission_reply: ${jsonEncode(callReply)}');
  final direction =
      callReply['direction']
          ?.toString() ??
      '';

  final connectedAt =
      callReply['call_connected_at'];

  final duration =
      callReply['call_duration_seconds'] ??
      callReply['call_duration'] ??
      callReply['duration'] ??
      0;

  final bool isConnected =
      connectedAt != null ||
      duration > 0;

  final bool isMissed =
      direction == "USER_INITIATED" &&
      !isConnected;

  final bool isCancelled =
      direction == "BUSINESS_INITIATED" &&
      !isConnected;

  String title = "Voice call";
  String subtitle = "";

  if (isConnected) {

    title = "Voice call";
    subtitle =
        "Call duration: ${duration}s";

  } else if (isMissed) {

    title = "Missed voice call";
    subtitle = "User didn't connect";

  } else if (isCancelled) {

    title = "Cancelled voice call";
    subtitle = "Call cancelled";

  }

  return BaseMessageUi(
    isSentByMe: isSentByMe,
    createdAt: createdAt,
    mediaQuery: mediaQuery,
    deliveryStatus: deliveryStatus,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSentByMe
            ? const Color(0xffDCF8C6)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [

          /// ================= ICON =================
          Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isMissed ||
                      isCancelled)
                  ? Colors.red
                      .withOpacity(0.12)
                  : Colors.green
                      .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMissed
                  ? Icons.call_missed
                  : isCancelled
                      ? Icons.call_end
                      : Icons.call,
              color: isMissed ||
                      isCancelled
                  ? Colors.red
                  : Colors.green,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          /// ================= TEXT =================
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                /// Title
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 4),

                /// Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

        /// =========================================
        /// Flow Reply
        /// =========================================
        else if (interactive['flow_reply'] != null) {

          final flowReply =
              interactive['flow_reply'];

          displayText =
              flowReply['flow_token'] ??
              'Flow response received';
        }
      }
    } catch (e) {

      displayText = 'Error parsing message';

      debugPrint(
        'Error parsing interactive message: $e',
      );
    }

    /// =========================================
    /// Default UI
    /// =========================================
    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          displayText,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// =========================================
  /// Format Interactive Response
  /// =========================================
  String _formatInteractiveResponse(
    Map<String, dynamic> responseJson,
  ) {

    final buffer = StringBuffer();

    responseJson.forEach((key, value) {

      if (value is List) {

        buffer.writeln(
          '${_formatKey(key)}: ${value.join(", ")}',
        );

      } else {

        buffer.writeln(
          '${_formatKey(key)}: $value',
        );
      }
    });

    return buffer.toString().trim();
  }

  /// =========================================
  /// Format Key
  /// =========================================
  String _formatKey(String key) {

    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (e) => e.isNotEmpty
              ? e[0].toUpperCase() +
                  e.substring(1)
              : '',
        )
        .join(' ');
  }
}