import 'package:flutter/material.dart';
import '../../themes/themes.dart';

class BaseMessageUi extends StatelessWidget {
  final Widget child;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;
  final bool isInTemplate; // New parameter for template-specific styling

  const BaseMessageUi({
    super.key,
    required this.child,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
    this.isInTemplate = false, // Default to false
  });

  // String get formattedTime {
  //   return "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";
  // }
  String get formattedTime {
    int hour = createdAt.hour;
    String period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12 == 0 ? 12 : hour % 12; // convert to 12hr

    String minute = createdAt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                mediaQuery.width * 0.7, // Maximum width of the message bubble
            //  maxHeight: mediaQuery.width * 0.8,
          ),
          margin: EdgeInsets.only(
            top: mediaQuery.height * 0.025,
            bottom: mediaQuery.height * 0.01,
            right: isSentByMe ? 0 : mediaQuery.height * 0.06,
            left: isSentByMe ? mediaQuery.height * 0.06 : 0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: mediaQuery.width * 0.03,
            vertical: mediaQuery.height * 0.011,
          ),
          decoration: BoxDecoration(
            color: isInTemplate
                ? Colors.transparent
                : (isSentByMe
                    ? AppTheme.messagesColor
                    : AppTheme.recivedMessageBg),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(isSentByMe ? 20 : 0),
              topLeft: Radius.circular(isSentByMe ? 22 : 20),
              topRight: Radius.circular(isSentByMe ? 22 : 20),
              bottomRight: Radius.circular(isSentByMe ? 0 : 20),
            ),
            boxShadow: isInTemplate
                ? [] // No shadow for template messages
                : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              child,
              SizedBox(height: mediaQuery.height * 0.01),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.messageTime,
                    ),
                  ),
                  SizedBox(width: mediaQuery.width * 0.01),
                  if (isSentByMe) ...[
                    if (deliveryStatus?.toLowerCase() == 'sent')
                      const Icon(Icons.check, size: 14, color: Colors.grey),
                    if (deliveryStatus?.toLowerCase() == 'delivered')
                      const Icon(Icons.done_all, size: 14, color: Colors.grey),
                    if (deliveryStatus?.toLowerCase() == 'read')
                      const Icon(Icons.done_all, size: 14, color: Colors.blue),
                    if (deliveryStatus?.toLowerCase() == 'failed') ...[
                      const Text(
                        "failed",
                        style: TextStyle(color: Colors.red),
                      ),
                      const Icon(Icons.error, size: 16, color: Colors.red)
                    ],
                    if (deliveryStatus?.toLowerCase() == 'sending')
                      const Icon(Icons.access_time_outlined,
                          size: 14, color: Colors.grey),
                    if (deliveryStatus?.toLowerCase() == 'pending')
                      const Icon(Icons.access_time_outlined,
                          size: 14, color: Colors.grey),
                  ],
                ],
              ), // Text(
              //   formattedTime,
              //   style: const TextStyle(fontSize: 10, color: Colors.grey),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
