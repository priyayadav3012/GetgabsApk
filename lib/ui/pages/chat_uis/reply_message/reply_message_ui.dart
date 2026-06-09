import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/document_message/document_message_ui_controller.dart';
import 'package:getgabs/ui/pages/chat_uis/media_preview_screen.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_doc_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_image_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_template_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_video_message_ui.dart';
import 'package:path/path.dart' as path;

class ReplyMessageUi extends StatelessWidget {
  final String replyText;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;
  final String replyFormData;

  const ReplyMessageUi({
    super.key,
    required this.replyText,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
    required this.replyFormData,
  });
  String get formattedTime {
    return "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";
  }

  void _showReplyPreview(BuildContext context) {
    final previewMediaQuery = Size(
      MediaQuery.of(context).size.width * 0.9,
      MediaQuery.of(context).size.height * 0.9,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(8),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Original Message',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: buildReplyMessageWidget(replyFormData, previewMediaQuery, isPreview: true),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    
    if (replyFormData.isEmpty) {
      return const Text('');
    }
    var reply = jsonDecode(replyFormData);
    var messageType = reply['message_type'];

    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showReplyPreview(context),
            child: Container(
              width: messageType == 'document'
                  ? mediaQuery.width * 0.5
                  : mediaQuery.width * 0.5,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  border: const Border(
                    left: BorderSide(
                      color: Colors.green,
                      width: 4.0,
                    ),
                  )),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: buildReplyMessageWidget(replyFormData, mediaQuery),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (replyText.isNotEmpty) // Show the reply text if it's not empty
            SelectableText(
              replyText,
              // softWrap: true,
              // overflow: TextOverflow.visible,
            ),
        ],
      ),
    );
  }

  Widget buildReplyMessageWidget(String message, Size mediaQuery, {bool isPreview = false}) {
    try {
      var reply = jsonDecode(message);
      var messageType = reply['message_type'];
      var messageText = reply['message_text'] ?? '';
      var templateData = reply['template_data'] ?? '';

      // Print the message type for debugging
      print('Message Type: $messageType');

      // Handle different message types
      if (messageType == 'text') {
        // Check if messageText is JSON (nested reply)
        String displayText = messageText;
        try {
          var parsedText = jsonDecode(messageText);
          if (parsedText is Map && parsedText.containsKey('text')) {
            displayText = parsedText['text']['body'] ?? messageText;
          }
        } catch (e) {
          // messageText is plain text, use as is
        }
        
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reply",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 43, 55, 231)),
              ),
              SelectableText(displayText)
            ]);
      } else if (messageType == 'template') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Reply",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 43, 55, 231)),
            ),
            ReplyTempleteMessageUi(
              templateData: templateData,
              messageText: messageText,
              mediaQuery: mediaQuery,
            ),
          ],
        );
      } else if (messageType == 'image') {
        final imageUrl = reply['local'] == true
            ? messageText
            : "https://app.getgabs.com/customers/mediafile/$messageText";
        
        // Create a widget to adjust the size of the grey container based on the image
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Reply",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 43, 55, 231)),
            ),
            if (isPreview)
              GestureDetector(
                onTap: () {
                  Get.to(() => MediaPreviewScreen(
                    mediaUrl: imageUrl,
                    isVideo: false,
                  ));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: mediaQuery.width * 0.85,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.error, size: 48, color: Colors.red),
                    ),
                    memCacheWidth: (mediaQuery.width * 0.85).toInt(),
                    maxWidthDiskCache: 1000,
                  ),
                ),
              )
            else
              Container(
                constraints: BoxConstraints(
                    maxWidth: mediaQuery.width * 0.22,
                    maxHeight: mediaQuery.height * 0.11
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 200, // Small cache for thumbnails
                    maxWidthDiskCache: 300,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.grey, size: 24),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      } else if (messageType == 'video') {
        final videoUrl = reply['local'] == true
            ? messageText
            : 'https://app.getgabs.com/customers/mediafile/$messageText';
        
        // Create a widget to adjust the size of the grey container based on the image
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Reply",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 43, 55, 231)),
            ),
            if (isPreview)
              GestureDetector(
                onTap: () {
                  Get.to(() => MediaPreviewScreen(
                    mediaUrl: videoUrl,
                    isVideo: true,
                  ));
                },
                child: Container(
                  width: mediaQuery.width * 0.85,
                  height: mediaQuery.height * 0.4,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Show video icon/thumbnail instead of loading actual video
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam,
                                size: 64,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to play video',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                constraints: BoxConstraints(
                    maxWidth: mediaQuery.width * 0.16,
                    maxHeight: mediaQuery.height * 0.06
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ReplyVideoMessageUi(
                    videoUrl: videoUrl,
                    mediaQuery: mediaQuery,
                  ),
                ),
              ),
          ],
        );
      } else if (messageType == 'document') {
        final documentUrl = reply['local'] == true
            ? messageText
            : 'https://app.getgabs.com/customers/mediafile/$messageText';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Reply",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 43, 55, 231)),
            ),
            if (isPreview)
              GetBuilder<DocumentController>(
                init: DocumentController(documentUrl, isLocal: reply['local'] == true),
                global: false,
                builder: (controller) {
                  String fileName = path.basename(documentUrl);
                  String fileExtension = path.extension(documentUrl).toLowerCase();
                  
                  return Container(
                    width: mediaQuery.width * 0.85,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _getDocumentIcon(fileExtension),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fileExtension.toUpperCase().replaceAll('.', ''),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Obx(() {
                          if (controller.isDownloading.value) {
                            return Column(
                              children: [
                                LinearProgressIndicator(
                                  value: controller.downloadProgress.value / 100,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${controller.downloadProgress.value}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  controller.downloadDocument();
                                },
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Download Document'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            );
                          }
                        }),
                      ],
                    ),
                  );
                },
              )
            else
              Container(
                constraints: BoxConstraints(
                    maxWidth: mediaQuery.width * 0.5,
                    maxHeight: mediaQuery.height * 0.09
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ReplyDocumentMessageUi(
                    documentFile: documentUrl,
                    mediaQuery: mediaQuery,
                  ),
                ),
              ),
          ],
        );
      } else if (messageType == 'reply_msg') {
        // Handle nested reply messages
        String displayText = 'Reply to a message';
        
        try {
          // Try to parse the nested message
          var nestedMessage = jsonDecode(messageText);
          if (nestedMessage is Map) {
            // Extract the actual text from nested reply
            if (nestedMessage.containsKey('text') && nestedMessage['text'] != null) {
              displayText = nestedMessage['text']['body'] ?? 'Reply to a message';
            } else if (nestedMessage.containsKey('type')) {
              displayText = 'Reply to ${nestedMessage['type']}';
            }
          }
        } catch (e) {
          // If parsing fails, use messageText as is
          displayText = messageText.isNotEmpty ? messageText : 'Reply to a message';
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Reply",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 43, 55, 231)),
            ),
            SelectableText(
              displayText,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        );
      }
    } catch (e) {
      // Print the error for debugging purposes
      print('Error decoding message: $e');
      print('Message content: $message');
    }

    // Default return statement if no conditions are met
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Reply",
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 43, 55, 231)),
        ),
        Text(
          "Unsupported message type",
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _getDocumentIcon(String fileExtension) {
    IconData iconData;
    Color iconColor;

    switch (fileExtension.toLowerCase()) {
      case '.pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case '.doc':
      case '.docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case '.xls':
      case '.xlsx':
        iconData = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case '.ppt':
      case '.pptx':
        iconData = Icons.slideshow;
        iconColor = Colors.orange;
        break;
      case '.txt':
        iconData = Icons.text_snippet;
        iconColor = Colors.grey;
        break;
      case '.zip':
      case '.rar':
        iconData = Icons.folder_zip;
        iconColor = Colors.amber;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.blueGrey;
    }

    return Icon(iconData, color: iconColor, size: 48);
  }
}

