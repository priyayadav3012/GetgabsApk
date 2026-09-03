import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/models/message_modal.dart';
import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/document_message/document_message_ui_controller.dart';
import 'package:getgabs/ui/pages/chat_uis/media_preview_screen.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_doc_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_image_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_video_message_ui.dart';
import 'package:path/path.dart' as path;

class ReplyMessageUi extends StatelessWidget {
  final String replyText;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;
  final String replyFormData;
  // WhatsApp-style: tapping the quoted preview scrolls the chat to the
  // original message instead of opening the full-content modal (that
  // modal is still reachable via long-press). Optional — omitted call
  // sites (no MessagesPageController in scope) just keep tap-to-preview.
  final void Function(String messageId)? onTapQuoted;
  // The id of the original message, when replyFormData couldn't be
  // resolved — lets the "can't load" placeholder retry on tap instead of
  // only ever loading silently in the background.
  final String? unresolvedQuotedMessageId;
  final void Function(String messageId)? onRetryLoadQuoted;

  const ReplyMessageUi({
    super.key,
    required this.replyText,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
    required this.replyFormData,
    this.onTapQuoted,
    this.unresolvedQuotedMessageId,
    this.onRetryLoadQuoted,
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
    // replyFormData carries the QUOTED/original message (for the little
    // preview box below) — it's null/empty for a reply sent from the web
    // app, which only gives us the new reply text plus the original
    // message's id, not its full content. Skip just the preview box in
    // that case rather than dropping the whole reply (including replyText)
    // silently, which is what returning an early empty Text did before.
    final hasQuotedPreview = replyFormData.isNotEmpty;
    String? quotedMessageType;
    String? quotedMessageId;
    String quotedSenderLabel = 'Reply';
    if (hasQuotedPreview) {
      try {
        final decoded = jsonDecode(replyFormData);
        quotedMessageType = decoded['message_type'];
        quotedMessageId = decoded['message_id']?.toString();
        final senderName = decoded['quoted_sender_name']?.toString();
        if (senderName != null && senderName.isNotEmpty) {
          quotedSenderLabel = senderName;
        }
      } catch (_) {
        // Malformed quoted data — still show replyText, just no preview box.
      }
    }

    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (hasQuotedPreview && quotedMessageType != null)
            GestureDetector(
              onTap: () {
                if (onTapQuoted != null &&
                    quotedMessageId != null &&
                    quotedMessageId.isNotEmpty) {
                  onTapQuoted!(quotedMessageId);
                } else {
                  _showReplyPreview(context);
                }
              },
              onLongPress: () => _showReplyPreview(context),
              child: Container(
                width: quotedMessageType == 'document'
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // WhatsApp-style: the QUOTED message's sender
                          // ("You" / teammate name / customer name) once,
                          // here — not a repeated generic "Reply" label
                          // inside every per-type branch below.
                          Text(
                            quotedSenderLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color.fromARGB(255, 43, 55, 231)),
                          ),
                          const SizedBox(height: 2),
                          buildReplyMessageWidget(replyFormData, mediaQuery),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      // Its own tap target, independent of the box's tap
                      // (scroll-to-original) / long-press (same preview) —
                      // an explicit "view" affordance instead of relying
                      // on the undiscoverable long-press alone.
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showReplyPreview(context),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (unresolvedQuotedMessageId != null &&
              unresolvedQuotedMessageId!.isNotEmpty)
            GestureDetector(
              onTap: () => onRetryLoadQuoted?.call(unresolvedQuotedMessageId!),
              child: Container(
                width: mediaQuery.width * 0.5,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade400, width: 4.0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "This message can't load…",
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (replyText.isNotEmpty) // Show the reply text if it's not empty
            _CollapsibleReplyText(text: replyText, isSentByMe: isSentByMe),
        ],
      ),
    );
  }

  Widget buildReplyMessageWidget(String message, Size mediaQuery, {bool isPreview = false}) {
    try {
      var reply = jsonDecode(message);
      var messageType = reply['message_type'];
      var messageText = reply['message_text'] ?? '';

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
        
        return SelectableText(displayText);
      } else if (messageType == 'template') {
        // A quoted preview should be a short one-liner (WhatsApp-style),
        // not the full template with header/image/buttons — that's what
        // ReplyTempleteMessageUi renders, which is too much for a preview.
        final preview = Message.fromJson(reply).previewText;
        return SelectableText(
          preview.isNotEmpty ? preview : 'Template',
          maxLines: 2,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        );
      } else if (messageType == 'image') {
        final imageUrl = reply['local'] == true
            ? messageText
            : Message.buildMediaUrl(messageText);
        
        // Create a widget to adjust the size of the grey container based on the image
        return isPreview
            ? GestureDetector(
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
            : Container(
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
              );
      } else if (messageType == 'video') {
        final videoUrl = reply['local'] == true
            ? messageText
            : Message.buildMediaUrl(messageText);
        
        // Create a widget to adjust the size of the grey container based on the image
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
            : Message.buildMediaUrl(messageText);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
        // Handle nested reply messages — i.e. this quoted message was
        // ITSELF a reply. Its own messageText is our {"msgcontent":...,
        // "message_id":...} shape (see sendMessage), not the older
        // {"text":{"body":...}} WhatsApp shape — check msgcontent first so
        // a reply-to-a-reply shows the actual text instead of the generic
        // "Reply to a message" fallback.
        String displayText = 'Reply to a message';

        try {
          var nestedMessage = jsonDecode(messageText);
          if (nestedMessage is Map) {
            if (nestedMessage['msgcontent'] != null &&
                nestedMessage['msgcontent'].toString().isNotEmpty) {
              displayText = nestedMessage['msgcontent'].toString();
            } else if (nestedMessage.containsKey('text') && nestedMessage['text'] != null) {
              displayText = nestedMessage['text']['body'] ?? 'Reply to a message';
            } else if (nestedMessage.containsKey('type')) {
              displayText = 'Reply to ${nestedMessage['type']}';
            }
          }
        } catch (e) {
          // If parsing fails, use messageText as is
          displayText = messageText.isNotEmpty ? messageText : 'Reply to a message';
        }

        return SelectableText(
          displayText,
          style: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
        );
      } else if (messageType == 'note') {
        // Team notes / assignment notes are stored as plain text (see
        // NoteMessageUi) — just show it directly instead of falling
        // through to "Unsupported message type".
        return SelectableText(
          messageText.isNotEmpty ? messageText : 'Note',
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        );
      } else {
        // Any other type this widget doesn't have a dedicated preview for
        // yet (interactive, buttons, location, contacts, audio, …) — reuse
        // Message.previewText's per-type extraction instead of a hardcoded
        // "Unsupported" label, so it degrades gracefully as new types show
        // up here rather than only after someone adds a case for them.
        final preview = Message.fromJson(reply).previewText;
        if (preview.isNotEmpty && !preview.trimLeft().startsWith('{')) {
          return SelectableText(preview,
              style: const TextStyle(fontSize: 13, color: Colors.black87));
        }
      }
    } catch (e) {
      // Print the error for debugging purposes
      print('Error decoding message: $e');
      print('Message content: $message');
    }

    // Default return statement if no conditions are met
    return const Text(
      "Unsupported message type",
      style: TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: Colors.grey,
      ),
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

// A received reply's own text can be just as long as any other message
// (e.g. a bot's multi-sentence greeting sent as a reply_msg) — collapse it
// to a short preview with a tap-to-expand, same treatment as TextMessageUi
// and TempleteMessageUi give long received messages. Sent-by-me replies
// are never collapsed.
class _CollapsibleReplyText extends StatefulWidget {
  final String text;
  final bool isSentByMe;

  const _CollapsibleReplyText({required this.text, required this.isSentByMe});

  @override
  State<_CollapsibleReplyText> createState() => _CollapsibleReplyTextState();
}

class _CollapsibleReplyTextState extends State<_CollapsibleReplyText> {
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

  @override
  Widget build(BuildContext context) {
    final canCollapse =
        !widget.isSentByMe && widget.text.length > _collapseThreshold;
    final collapsed = canCollapse && !_expanded;

    Widget content;
    if (collapsed) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expand,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
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
      content = SelectableText(widget.text);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _flashHighlight ? const Color(0xFFD3E3FD) : Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topLeft,
        child: content,
      ),
    );
  }
}

