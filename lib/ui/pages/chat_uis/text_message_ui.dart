import 'package:flutter/material.dart';
import 'base_message_ui.dart';

class TextMessageUi extends StatefulWidget {
  final String text;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;

  const TextMessageUi({super.key,
    required this.text,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
      required this.deliveryStatus
  });

  @override
  State<TextMessageUi> createState() => _TextMessageUiState();
}

class _TextMessageUiState extends State<TextMessageUi> {
  // Long received messages start collapsed to a short preview (tap to
  // reveal the full text) — sent-by-me messages are never collapsed, and
  // a short received message has nothing worth condensing either. Once
  // expanded it stays expanded.
  static const int _collapseThreshold = 80;
  bool _expanded = false;
  bool _flashHighlight = false;

  void _expand() {
    setState(() {
      _expanded = true;
      _flashHighlight = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _flashHighlight = false);
    });
  }

  // Detect URLs in text using regex
  List<TextSpan> _buildTextSpans(BuildContext context, String text) {
    final urlRegex = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // Add the URL as styled text (not clickable, but selectable)
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: Colors.blue.shade700,
            decoration: TextDecoration.underline,
            decorationColor: Colors.blue.shade700,
            decorationThickness: 1.0,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text after last URL
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final canCollapse =
        !widget.isSentByMe && widget.text.length > _collapseThreshold;
    final collapsed = canCollapse && !_expanded;
    final spans = _buildTextSpans(context, widget.text);
    const baseStyle = TextStyle(color: Colors.black, fontSize: 16);

    Widget content;
    if (collapsed) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expand,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(children: spans, style: baseStyle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.unfold_more, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Tap to view full message',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      content = SelectableText.rich(
        TextSpan(children: spans, style: baseStyle),
        enableInteractiveSelection: true,
      );
    }

    return BaseMessageUi(
      isSentByMe: widget.isSentByMe,
      createdAt: widget.createdAt,
      mediaQuery: widget.mediaQuery,
      deliveryStatus: widget.deliveryStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _flashHighlight ? const Color(0xFFD3E3FD) : Colors.transparent,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topLeft,
          child: content,
        ),
      ),
    );
  }
}
