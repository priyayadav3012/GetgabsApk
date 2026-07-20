import 'package:flutter/material.dart';
import '../../../../data/models/message_modal.dart';

/// Renders a system "note" message (assignment / co-assignment /
/// unassignment / plain team note) as a full-width card with a colored
/// header strip, instead of a left/right chat bubble. Shared by both the
/// active-chat screen and the rolling-over chat screen so a note looks and
/// behaves identically wherever it's loaded from (a fresh assign, a socket
/// push, or a normal history reload).
///
/// The backend doesn't reliably send `note_type`/`note_created_by` on every
/// path (confirmed missing on plain history reloads), so both are inferred
/// from the note's own content text when the dedicated fields are empty —
/// that keeps the label/name correct everywhere instead of only right after
/// the Assign dialog's one-time insert.
class NoteMessageUi extends StatelessWidget {
  final Message message;
  final Size mediaQuery;

  const NoteMessageUi({
    super.key,
    required this.message,
    required this.mediaQuery,
  });

  static const _headerColor = Color(0xFF8B5CF6);
  static const _headerBg = Color(0xFFEDE4FF);
  static const _bodyBg = Color(0xFFF7F3FF);

  ({IconData icon, String label}) _resolveLabel(String content) {
    final type = message.noteType?.toLowerCase() ?? '';
    if (type == 'team_co_assignment') {
      return (icon: Icons.group_add_outlined, label: 'CO-ASSIGNMENT');
    }
    if (type == 'team_unassignment') {
      return (icon: Icons.person_remove_outlined, label: 'UNASSIGNMENT');
    }
    if (type == 'team_assignment') {
      return (icon: Icons.person_outline, label: 'ASSIGNMENT');
    }

    // note_type missing/unrecognized — infer from the content text instead.
    final lower = content.toLowerCase();
    if (lower.contains('co-assign') || lower.contains('co assign')) {
      return (icon: Icons.group_add_outlined, label: 'CO-ASSIGNMENT');
    }
    if (lower.contains('unassign')) {
      return (icon: Icons.person_remove_outlined, label: 'UNASSIGNMENT');
    }
    if (lower.contains('assign')) {
      return (icon: Icons.person_outline, label: 'ASSIGNMENT');
    }
    return (icon: Icons.sticky_note_2_outlined, label: 'NOTE');
  }

  /// Pulls a leading name out of content like "Rahul Sharma assigned to this
  /// chat" or "Rahul Sharma co-assigned to this chat" when note_created_by
  /// itself is empty.
  String _inferCreatedBy(String content) {
    final match = RegExp(
      r'^(.{2,40}?)\s+(?:co-assigned|co assigned|assigned|unassigned)\b',
      caseSensitive: false,
    ).firstMatch(content.trim());
    return match?.group(1)?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final content = message.messageText;
    final resolved = _resolveLabel(content);
    final createdBy = (message.noteCreatedBy?.isNotEmpty ?? false)
        ? message.noteCreatedBy!
        : _inferCreatedBy(content);

    int hour = message.createdAt.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12 == 0 ? 12 : hour % 12;
    final minute = message.createdAt.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute $period';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: mediaQuery.width * 0.06,
        vertical: mediaQuery.height * 0.01,
      ),
      decoration: BoxDecoration(
        color: _bodyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _headerBg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: _headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(resolved.icon, size: 16, color: _headerColor),
                const SizedBox(width: 6),
                Text(
                  resolved.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: _headerColor,
                  ),
                ),
                if (createdBy.isNotEmpty) ...[
                  const Spacer(),
                  Text(createdBy,
                      style: const TextStyle(fontSize: 12, color: _headerColor)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(content, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(time,
                      style: TextStyle(fontSize: 11, color: _headerColor.withOpacity(0.7))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
