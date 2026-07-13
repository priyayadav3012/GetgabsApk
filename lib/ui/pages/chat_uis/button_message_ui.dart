import 'dart:convert';
import 'package:flutter/material.dart';
import 'base_message_ui.dart';

class ButtonMessageUi extends StatelessWidget {
  final String text; // This will hold the JSON string
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;

  const ButtonMessageUi({
    super.key,
    required this.text,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Variable to hold extracted button text
    String buttonText = "Button";

    if (text.isNotEmpty) {
      try {
        // Decode the JSON string
        final Map<String, dynamic> messageJson = json.decode(text);

        // Extract button text and sender info if available
        buttonText = messageJson['button']?['text'] ?? "";
      } catch (e) {
        // Handle JSON parsing errors
        print("Error decoding message_text: $e");
      }
    }

    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const SizedBox(height: 5), SelectableText(buttonText)],
      ),
    );
  }
}
