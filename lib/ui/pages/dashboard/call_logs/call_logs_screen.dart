import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/models/call_log_model.dart';
import 'package:getgabs/domain/controllers/dashboard/call_logs/call_logs_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/messages_page.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CALL LOGS TAB — dashboard-level bottom-nav screen (Chats / Call Logs / More)
//  Backed by CallLogsController: paginated fetch + infinite scroll.
// ─────────────────────────────────────────────────────────────────────────────
class CallLogsScreen extends StatelessWidget {
  const CallLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CallLogsController());
    final wp = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.black87, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Call Logs',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: wp * 0.065,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(controller, wp),
      ),
    );
  }

  Widget _buildBody(CallLogsController controller, double w) {
    return Obx(() {
      if (controller.isLoading.value && controller.callLogs.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: Colors.orange));
      }

      if (controller.error.value.isNotEmpty && controller.callLogs.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            Text(controller.error.value,
                style: TextStyle(color: Colors.grey[500], fontSize: w * 0.036)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: controller.refreshCallLogs,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ]),
        );
      }

      if (controller.callLogs.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call_end, color: Colors.grey[300], size: 56),
            const SizedBox(height: 12),
            Text(
              'No call logs found',
              style: TextStyle(color: Colors.grey[500], fontSize: w * 0.036),
            ),
          ]),
        );
      }

      return RefreshIndicator(
        color: Colors.orange,
        onRefresh: controller.refreshCallLogs,
        child: ListView.separated(
          controller: controller.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount:
              controller.callLogs.length + (controller.isLoadingMore.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= controller.callLogs.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.orange)),
              );
            }
            final entry = CallLogEntry.fromJson(controller.callLogs[index]);
            return CallLogRow(entry: entry, screenW: w);
          },
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIST ROW
// ─────────────────────────────────────────────────────────────────────────────
class CallLogRow extends StatelessWidget {
  final CallLogEntry entry;
  final double screenW;

  const CallLogRow({super.key, required this.entry, required this.screenW});

  static const List<Color> _avatarColors = [
    Color(0xFF7FDBC7), // teal
    Color(0xFFF6D186), // amber
    Color(0xFFC9E4A5), // light green
    Color(0xFFF3B7C2), // pink
    Color(0xFFA9C9F5), // light blue
    Color(0xFFD3B8F0), // light purple
  ];

  String get _initials {
    final name = entry.customerName.trim().isNotEmpty
        ? entry.customerName.trim()
        : entry.phoneNumber;
    if (name.isEmpty) return '#';
    final words = name.split(RegExp(r'\s+'));
    if (words.length == 1) return words[0].substring(0, 1).toUpperCase();
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  Color get _avatarColor {
    final key = entry.customerName.isNotEmpty
        ? entry.customerName
        : entry.phoneNumber;
    final hash = key.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _avatarColors[hash % _avatarColors.length];
  }

  String get _durationLabel {
    if (entry.isMissed) return '-';
    final seconds = entry.callDurationSeconds;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String get _dateTimeLabel {
    final t = entry.callTime;
    final datePart = DateFormat('MMMM d').format(t);
    final timePart = DateFormat('h:mm a').format(t).toLowerCase();
    return '$datePart at $timePart';
  }

  void _openChat() {
    final profile = entry.profile;
    if (profile == null) {
      Get.snackbar(
        'Unavailable',
        'Could not open chat for this call',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEA4335),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
      );
      return;
    }
    Get.to(() => MessagesPage(
          profile: profile,
          profileWaKey: profile.profileWaKey,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.isMissed ? Colors.red : const Color(0xFF1E8E5A);
    final directionColor = entry.isMissed ? Colors.red : Colors.blue.shade600;
    final directionIcon = entry.isMissed
        ? (entry.isOutgoing ? Icons.call_missed_outgoing : Icons.call_missed)
        : (entry.isOutgoing ? Icons.call_made : Icons.call_received);
    final directionLabel = entry.isMissed
        ? (entry.isOutgoing ? 'No answer' : 'Missed')
        : (entry.isOutgoing ? 'Outgoing' : 'Incoming');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenW * 0.03),
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.035,
        vertical: screenW * 0.03,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _avatarColor),
            child: Text(
              _initials,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 14),
            ),
          ),
          SizedBox(width: screenW * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.customerName.isNotEmpty
                      ? entry.customerName
                      : entry.phoneNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: screenW * 0.038,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                if (entry.customerName.isNotEmpty) ...[
                  SizedBox(height: screenW * 0.006),
                  Text(
                    entry.phoneNumber,
                    style: TextStyle(
                        fontSize: screenW * 0.032, color: Colors.grey[500]),
                  ),
                ],
                SizedBox(height: screenW * 0.01),
                Row(
                  children: [
                    Icon(directionIcon, size: 14, color: directionColor),
                    const SizedBox(width: 4),
                    Text(
                      directionLabel,
                      style: TextStyle(
                        fontSize: screenW * 0.032,
                        color: directionColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '  |  $_dateTimeLabel',
                      style: TextStyle(
                          fontSize: screenW * 0.032, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: screenW * 0.02),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _durationLabel,
                style: TextStyle(
                    fontSize: screenW * 0.036,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              SizedBox(height: screenW * 0.02),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openChat,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.chat_bubble_outline,
                      size: 18, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
