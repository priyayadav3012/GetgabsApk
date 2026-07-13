import 'package:flutter/material.dart';
import 'base_message_ui.dart';

class TextMessageUi extends StatelessWidget {
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
            // fontWeight: FontWeight.bold,
            // backgroundColor: Colors.blue.shade100,
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
    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: SelectableText.rich(
        TextSpan(
          children: _buildTextSpans(context, text),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        enableInteractiveSelection: true,
      ),
    );
  }
}