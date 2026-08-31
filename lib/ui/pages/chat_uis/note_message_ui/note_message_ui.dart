import 'package:flutter/material.dart';
import '../../../../data/models/message_modal.dart';
import '../../../../domain/controllers/dashboard/messages_page/messages_page_controller.dart';

/// Renders a system "note" message (assignment / co-assignment /
/// unassignment / plain team note) as a full-width card, instead of a
/// left/right chat bubble. Shared by both the active-chat screen and the
/// rolling-over chat screen so a note looks and behaves identically
/// wherever it's loaded from (a fresh assign, a socket push, or a normal
/// history reload).
///
/// The backend doesn't reliably send `note_type`/`note_created_by` on every
/// path (confirmed missing on plain history reloads), so both are inferred
/// from the note's own content text when the dedicated fields are empty —
/// that keeps the label/name correct everywhere instead of only right after
/// the Assign dialog's one-time insert.
class NoteMessageUi extends StatelessWidget {
  final Message message;
  final Size mediaQuery;
  final MessagesPageController? controller;

  const NoteMessageUi({
    super.key,
    required this.message,
    required this.mediaQuery,
    this.controller,
  });

  static const _headerColor = Color(0xFF8B5CF6);
  static const _headerBg = Color(0xFFEDE4FF);
  static const _bodyBg = Color(0xFFF7F3FF);

  // Plain team note — yellow card, distinct from the assignment-family
  // notes below (which keep the purple treatment).
  static const _teamNoteBg = Color(0xFFFFF6D9);
  static const _teamNoteBorder = Color(0xFFF0DFA0);
  static const _teamNoteAccent = Color(0xFFB8860B);
  static const _mentionColor = Color(0xFF1565C0);

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

  String _formattedTime() {
    int hour = message.createdAt.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12 == 0 ? 12 : hour % 12;
    final minute = message.createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Splits note text on "@handle" mentions so they render in
  /// [_mentionColor] instead of the plain body color.
  List<TextSpan> _highlightMentions(String content, TextStyle baseStyle) {
    final mentionPattern = RegExp(r'@[A-Za-z0-9_]+');
    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final match in mentionPattern.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(
            TextSpan(text: content.substring(lastEnd, match.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: baseStyle.copyWith(
            color: _mentionColor, fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd), style: baseStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final content = message.messageText;
    final resolved = _resolveLabel(content);
    final time = _formattedTime();

    // Plain team note (not an assignment/co-assignment/unassignment) gets
    // the yellow "TEAM NOTE" card design; everything else keeps the
    // existing purple assignment-family treatment untouched below.
    if (resolved.label == 'NOTE') {
      final senderName = controller?.resolveSenderDisplayName(message);

      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(
          horizontal: mediaQuery.width * 0.06,
          vertical: mediaQuery.height * 0.01,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _teamNoteBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _teamNoteBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.star_border,
                    size: 16, color: _teamNoteAccent),
                const SizedBox(width: 6),
                const Text(
                  'TEAM NOTE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: _teamNoteAccent,
                  ),
                ),
                if (senderName != null && senderName.isNotEmpty) ...[
                  const Spacer(),
                  Text(senderName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _teamNoteAccent)),
                ],
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: _teamNoteBorder),
            ),
            RichText(
              text: TextSpan(
                children: _highlightMentions(
                  content,
                  const TextStyle(fontSize: 13.5, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(time,
                  style:
                      TextStyle(fontSize: 11, color: _teamNoteAccent.withOpacity(0.75))),
            ),
          ],
        ),
      );
    }

    final createdBy = (message.noteCreatedBy?.isNotEmpty ?? false)
        ? message.noteCreatedBy!
        : _inferCreatedBy(content);

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
