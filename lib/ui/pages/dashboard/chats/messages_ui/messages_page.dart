import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/ui/pages/chat_uis/contact_message_ui/contact_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/interactive_message/interactive_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/shortmessagesheet.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../data/models/active_chat_model.dart';
import '../../../../../data/models/message_modal.dart';
import '../../../chat_uis/audio_message_ui/audio_message_ui.dart';
import '../../../chat_uis/base_message_ui.dart';
import '../../../chat_uis/button_message_ui.dart';
import '../../../chat_uis/document_message/document_message_ui.dart';
import '../../../chat_uis/image_message_ui/image_message_ui.dart';
import '../../../chat_uis/location_message_ui/location_message_ui.dart';
import '../../../chat_uis/order_message/order_message_ui.dart';
import '../../../chat_uis/reply_message/reply_message_ui.dart';
import '../../../chat_uis/text_message_ui.dart';
import '../rolling_over_chats.dart/rolling_message_ui/send_template.dart';
import '../templates_folder/bottom_sheet/bottom_sheet_controller/bottom_sheet_controller.dart';
import '../templates_folder/bottom_sheet/template_bottom_sheet.dart';

class MessagesPage extends StatelessWidget {
  final Profile profile;
  final String profileWaKey;

  const MessagesPage(
      {super.key, required this.profile, required this.profileWaKey});

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    // var messagesPageController = Get.find<MessagesPageController>();
    final MessagesPageController messagesPageController = Get.put(
        MessagesPageController(
            profileWaKey, profile.profileWaId, 'active', profile));

    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: AppBar(
        elevation: 4,
        shadowColor: AppTheme.black54,
        backgroundColor: AppTheme.whiteColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.back();
            messagesPageController.currentPage.value = 1;
          },
        ),
        title: Obx(() => Row(
              // Wrap the reactive part in Obx
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?name=${messagesPageController.replaceFirstTwoSpaces(messagesPageController.userProfile.value.profileName)}',
                  ),
                ),
                SizedBox(width: mediaQuery.width * 0.025),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messagesPageController.userProfile.value.profileName,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        messagesPageController.userProfile.value.profileWaId
                            .toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            )),
        actions: [
          Obx(() => IconButton(
                onPressed: messagesPageController.isAiToggleLoading.value
                    ? null // disabled while API call is in progress
                    : () => messagesPageController.toggleAiPause(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: messagesPageController.isAiPaused.value
                        ? const Color(0xFFFF5722).withOpacity(0.1)
                        : const Color(0xFF2196F3).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: messagesPageController.isAiToggleLoading.value
                      // Loading spinner while API call is in progress
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: messagesPageController.isAiPaused.value
                                ? const Color(0xFFFF5722)
                                : const Color(0xFF2196F3),
                          ),
                        )
                      // Normal icon
                      : Icon(
                          messagesPageController.isAiPaused.value
                              ? Icons.play_circle_outline // Resume AI
                              : Icons.pause_circle_outline, // Pause AI
                          color: messagesPageController.isAiPaused.value
                              ? const Color(0xFFFF5722)
                              : const Color(0xFF2196F3),
                          size: 20,
                        ),
                ),
                tooltip: messagesPageController.isAiToggleLoading.value
                    ? 'Updating...'
                    : messagesPageController.isAiPaused.value
                        ? 'Resume AI'
                        : 'Pause AI',
              )),
          // Call Button - Opens WhatsApp-style calling
          IconButton(
            onPressed: () {
              WhatsAppCallingConfig.showCallOptions(
                context,
                messagesPageController.userProfile.value.profileWaId.toString(),
                messagesPageController.userProfile.value.profileName,
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00A884).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call,
                color: Color(0xFF00A884),
                size: 20,
              ),
            ),
            tooltip: 'Call',
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final focus = FocusScope.of(context);
            if (!focus.hasPrimaryFocus) {
              focus.unfocus(); // ✅ keyboard hide without breaking selection
            }
          },
          child: Column(
            children: [
              /// ================= CHAT LIST =================
              Expanded(
                child: Obx(() {
                  if (messagesPageController.groupedMessages.isEmpty) {
                    return const SizedBox();
                  }

                  return ListView.builder(
                    reverse: true,
                    controller: messagesPageController.scrollController,
                    itemCount:
                        messagesPageController.groupedMessages.keys.length,
                    itemBuilder: (context, index) {
                      final date = messagesPageController.groupedMessages.keys
                          .toList()[index];
                      final messages =
                          messagesPageController.groupedMessages[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// ---------- Date Header ----------
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          /// ---------- Messages ----------
                          ...messages.map(
                            (message) =>
                                buildMessageWidget(message, mediaQuery),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ),

              // const Divider(height: 1),
              const Divider(),

              /// ================= INPUT FIELD =================
              _buildInputField(
                messagesPageController,
                profileWaKey,
                mediaQuery,
                context,
              ),

              SizedBox(height: mediaQuery.height * 0.01),
            ],
          ),
        ),
      ),

      // body: SafeArea(
      //   child: TapRegion(
      //     onTapOutside: (_) =>
      //         FocusScope.of(context).unfocus(), // hides keyboard on outside tap
      //     child: Column(children: [
      //       Expanded(
      //         child: NotificationListener<UserScrollNotification>(
      //           onNotification: (_) {
      //             FocusScope.of(context).unfocus(); // hides keyboard on scroll
      //             return false;
      //           },
      //           child: Obx(() {
      //             if (messagesPageController.groupedMessages.isNotEmpty) {
      //               return ListView.builder(
      //                 reverse: true,
      //                 itemCount:
      //                   messagesPageController.groupedMessages.keys.length,
      //               controller: messagesPageController.scrollController,
      //               itemBuilder: (context, index) {
      //                 String date = messagesPageController.groupedMessages.keys
      //                     .toList()[index];
      //                 List<Message> messages =
      //                     messagesPageController.groupedMessages[date]!;
      //                 return Column(
      //                   crossAxisAlignment: CrossAxisAlignment.start,
      //                   children: [
      //                     Align(
      //                       alignment: Alignment.center,
      //                       child: Container(
      //                         margin: const EdgeInsets.symmetric(vertical: 8),
      //                         padding: const EdgeInsets.symmetric(
      //                             horizontal: 12, vertical: 6),
      //                         // decoration: BoxDecoration(
      //                         //   gradient: LinearGradient(
      //                         //     colors: [Colors.grey.shade300, Colors.grey],
      //                         //     begin: Alignment.topLeft,
      //                         //     end: Alignment.bottomRight,
      //                         //   ),
      //                         //   borderRadius: BorderRadius.circular(10),
      //                         //   boxShadow: [
      //                         //     BoxShadow(
      //                         //       color: Colors.grey.shade500,
      //                         //       offset: const Offset(0, 2),
      //                         //       blurRadius: 4,
      //                         //     ),
      //                         //   ],
      //                         // ),
      //                         child: Text(
      //                           date,
      //                           style: const TextStyle(
      //                               color: Colors.grey,
      //                               fontWeight: FontWeight.bold,
      //                               fontSize: 14),
      //                         ),
      //                       ),
      //                     ),
      //                     ...messages.map((message) {
      //                       return buildMessageWidget(message, mediaQuery);
      //                     }),
      //                   ],
      //                 );
      //               },
      //             );
      //           } else {
      //             return const Text("");
      //           }
      //         }),
      //       ),),
      //       const Divider(),
      //       _buildInputField(
      //           messagesPageController, profileWaKey, mediaQuery, context),
      //       SizedBox(
      //         height: mediaQuery.height * 0.01,
      //       )
      //     ]),
      //   ),
      // ),
    );
  }

  Widget buildMessageWidget(Message message, Size mediaQuery) {
  //   if (message.messageType == 'text') {
  // return TextMessageUi(
  //   text: message.messageText, // ← messageText ki jagah
  //   isSentByMe: message.sender == 1 ? false : true,
  //   createdAt: message.createdAt,
  //   mediaQuery: mediaQuery,
  //   deliveryStatus: message.deliveryStatus ?? "sent",
  // );

  //   } 
  // ✅ BAAD — parentheses se fix
if (message.messageType == 'text') {
  String displayText = message.messageText;
  try {
    final decoded = jsonDecode(message.messageText);
    final body = decoded['text']?['body']?.toString();
    if (body != null && body.isNotEmpty) displayText = body;
  } catch (_) {}
  return TextMessageUi(
    text: message.messageText, // ← messageText ki jagah displayText
    isSentByMe: message.sender == 1 ? false : true,
    createdAt: message.createdAt,
    mediaQuery: mediaQuery,
    deliveryStatus: message.deliveryStatus ?? "sent",
  );

} else if (message.messageType == 'template') {
  
  // ✅ templateData hai — real template
  if (message.templateData != null && message.templateData!.isNotEmpty) {
    return TempleteMessageUi(
      templateData: message.templateData,
      messageText: message.messageText,
      isSentByMe: message.sender == 1 ? false : true,
      createdAt: message.createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: message.deliveryStatus ?? "sent",
      messageType: message.messageType,
      senderName: '',
    );
  }

  // ✅ templateData null — short message type check karo
  final msgText = message.messageText;
  try {
    final decoded = jsonDecode(msgText);
    final type = decoded['type']?.toString() ?? '';

    if (type == 'text') {
      final body = decoded['text']?['body']?.toString() ?? '';
      return TextMessageUi(
        text: body.isNotEmpty ? body : msgText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    }

    if (type == 'document') {
      final doc = decoded['document'];
      final link = doc?['link']?.toString() ?? '';
      return DocumentMessageUi(
        documentFile: link,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: mediaQuery.height * 0.06,
        isInTemplate: false,
        isLocal: false,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    }

    if (type == 'image') {
      final img = decoded['image'];
      final link = img?['link']?.toString() ?? '';
      final caption = img?['caption']?.toString() ?? '';
      return ImageMessageUi(
        imageFile: null,
        imageUrl: link,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 10.0,
        leftMargin: 10.0,
        deliveryStatus: message.deliveryStatus ?? "sent",
        caption: caption,
      );
    }

    if (type == 'video') {
      final vid = decoded['video'];
      final link = vid?['link']?.toString() ?? '';
      return VideoMessageUi(
        videoUrl: link,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: mediaQuery.height * 0.06,
        isInTemplate: false,
        isLocal: false,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    }

    if (type == 'interactive') {
      final interactive = decoded['interactive'];
      final bodyText = interactive?['body']?['text']?.toString() ?? '';
      final buttons = interactive?['action']?['buttons'] as List? ?? [];
      return BaseMessageUi(
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bodyText.isNotEmpty)
              SelectableText(bodyText,
                  style: const TextStyle(color: Colors.black87)),
            if (buttons.isNotEmpty) ...[
              const Divider(height: 20, thickness: 1, color: Colors.grey),
              ...buttons.map((btn) {
                final title = btn['reply']?['title']?.toString() ?? '';
                return TextButton(
                  onPressed: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app, size: 16),
                      const SizedBox(width: 8),
                      Text(title),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );
    }

    // ✅ type == 'template' — messageText mein template JSON hai
    if (type == 'template') {
      return TempleteMessageUi(
        templateData: message.templateData,
        messageText: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        messageType: message.messageType,
        senderName: '',
      );
    }

  } catch (_) {}

  // fallback
  return TextMessageUi(
    text: msgText,
    isSentByMe: message.sender == 1 ? false : true,
    createdAt: message.createdAt,
    mediaQuery: mediaQuery,
    deliveryStatus: message.deliveryStatus ?? "sent",
  );
}
    else if (message.messageType == 'image') {
      return ImageMessageUi(
        imageFile: message.local ? File(message.messageText) : null,
        imageUrl: message.local
            ? message.messageText
            : "https://app.getgabs.com/customers/mediafile/${message.messageText}",
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 10.0,
        leftMargin: 10.0,
        deliveryStatus: message.deliveryStatus ?? "sent",
        caption: message.captionText == null
            ? "yyyyyyyyyyyyyyyyyyyyyyyyy"
            : message.captionText!,
      );
    } else if (message.messageType == 'audio') {
      return AudioMessageUi(
        audioUrl: message.local
            ? message.messageText
            : 'https://app.getgabs.com/customers/mediafile/${message.messageText}',
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: 0,
        isInTemplate: false,
        // isLocal: message.local,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'video') {
// loadThumbnailFromUrl('https://app.getgabs.com/customers/mediafile/${message.messageText}');
// return _buildThumbnailView('https://app.getgabs.com/customers/mediafile/${message.messageText}');
      return VideoMessageUi(
        videoUrl: message.local
            ? message.messageText
            : 'https://app.getgabs.com/customers/mediafile/${message.messageText}',
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: mediaQuery.height * 0.06,
        isInTemplate: false,
        isLocal: message.local,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'document') {
      return DocumentMessageUi(
        documentFile: message.local
            ? message.messageText
            : "https://app.getgabs.com/customers/mediafile/${message.messageText}",
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: mediaQuery.height * 0.06,
        isInTemplate: false,
        isLocal: message.local,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'contacts') {
      return ContactMessageUi(
        documentFile: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: mediaQuery.height * 0.06,
        isInTemplate: false,
        isLocal: message.local,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'location') {
      debugPrint("message.messageText");
      return LocationMessageUi(
        location: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'interactive') {
      return InteractiveMessageUi(
        messageText: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'buttons') {
      return TempleteMessageUi(
        templateData: message.templateData,
        messageText: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        messageType: message.messageType,
        senderName: profile.profileName,
      );
    } else if (message.messageType == 'reply_msg') {
      var isInJson = isJson(message.messageText);
      if (isInJson) {
        final messageData = jsonDecode(message.messageText);
        var replyText = messageData['text']?['body'] ?? "No reply text";
        return ReplyMessageUi(
          replyText: replyText,
          isSentByMe: message.sender == 1 ? false : true,
          createdAt: message.createdAt,
          mediaQuery: mediaQuery,
          deliveryStatus: message.deliveryStatus ?? "sent",
          replyFormData: message.replyformsg!,
        );
      } else {
        /*  final mess =
            '{\"context\":{\"forwarded\":true},\"from\":\"\",\"id\":\"\",\"timestamp\":\"\",\"text\":{\"body\":\"${message.messageText}\"},\"type\":\"image\"}';

        final messageData = jsonDecode(mess);
        print(
            '```````````````````````ljjsdlfjklsdjflkjsdklf```````````````````````');
        print(messageData);
        var replyText = messageData['text']?['body'] ?? "No reply text";
        print(replyText);
*/
        String firstWord = '';
        if (message.mediaType != null) {
          firstWord = message.mediaType!.split('/')[0];
        }

        // Get the part before "/"

        debugPrint(firstWord); // Output: image
        if (firstWord == 'image') {
          firstWord = 'image';
        } else {
          firstWord = 'text';
        }
        final replyforMessage =
            '{\"message_id\": \"=\", \"message_text\": \"${message.messageText}\", \"message_type\": \"$firstWord\"}';

        return ReplyMessageUi(
          replyText: '',
          isSentByMe: message.sender == 1 ? false : true,
          createdAt: message.createdAt,
          mediaQuery: mediaQuery,
          deliveryStatus: message.deliveryStatus ?? "sent",
          replyFormData: replyforMessage,
        );
      }
    } else if (message.messageType == 'button') {
      return ButtonMessageUi(
        text: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'order') {
      return OrderMessageUi(
        text: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else {
      // Unrecognized messageType (e.g. an auto-generated/system message
      // whose type isn't one of the cases above) used to render as a
      // totally blank bubble. Fall back to showing the raw text/body
      // instead of dropping the content silently.
      String displayText = message.messageText;
      try {
        final decoded = jsonDecode(message.messageText);
        if (decoded is Map) {
          final body = decoded['text']?['body']?.toString() ??
              decoded['body']?.toString() ??
              decoded['caption']?.toString();
          if (body != null && body.isNotEmpty) displayText = body;
        }
      } catch (_) {}
      if (displayText.trim().isEmpty) {
        displayText = '[${message.messageType}]';
      }

      return BaseMessageUi(
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            SelectableText(displayText),
          ],
        ),
      );
    }
  }

  bool isJson(String str) {
    try {
      jsonDecode(str); // Try to decode
      return true;
    } catch (e) {
      return false; // Return false if decoding fails
    }
  }
Widget _templateRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
//------------------------------------------------------------thumbnail-------------
  Future<File?> generateVideoThumbnail(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: url,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.WEBP,
        maxHeight: 64,
        quality: 75,
      );

      return thumbnailPath != null ? File(thumbnailPath.path) : null;
    } catch (e) {
      debugPrint("Error generating thumbnail: $e");
      return null;
    }
  }

  Widget _buildThumbnailView(String url) {
    return FutureBuilder<File?>(
      future: generateVideoThumbnail(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data != null) {
          return GestureDetector(
            onTap: () {
              // Get.to(() => MediaPreviewScreen(
              //       mediaUrl: videoUrl,
              //       isVideo: true,
              //     ));
            },
            child: Container(
              margin: const EdgeInsets.only(top: 23),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    kIsWeb
                        ? Image.network(snapshot.data!.path, fit: BoxFit.cover)
                        : Image.file(snapshot.data!, fit: BoxFit.cover),
                    const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 50,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return const Center(child: Text("Failed to load thumbnail"));
        }
      },
    );
  }
}

void loadThumbnailFromUrl(String url) async {
  XFile thumbnailFile = await VideoThumbnail.thumbnailFile(
    video: url,
    thumbnailPath: (await getTemporaryDirectory()).path,
    imageFormat: ImageFormat.WEBP,
    maxHeight:
        64, // specify the height of the thumbnail, let the width auto-scaled to keep the source aspect ratio
    quality: 75,
  );

  final image = kIsWeb
      ? Image.network(thumbnailFile.path)
      : Image.file(File(thumbnailFile.path));
  print(image);
}
//------------------------------------------------------------thumbnail-------------

void _openBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled:
        true, // Set to true if you want the bottom sheet to take full height
    builder: (BuildContext context) {
      return BottomSheetWidget(); // Call the BottomSheetWidget
    },
  ).whenComplete(() {
    // When the bottom sheet is dismissed, destroy the controller
    Get.delete<BottomSheetController>();
  });
}

Widget _buildInputField(
    MessagesPageController messagesPageController,
    var profileWaKey,
    Size mediaQuery,
    BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white,
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: () {
            Get.bottomSheet(
              elevation: 0,
              backgroundColor: Colors.transparent,
              SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(10),
                  child: Card(
                    elevation: 8,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.width * 0.05,
                        vertical: mediaQuery.height * 0.02,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Attachments",
                            style: TextStyle(
                              fontSize: mediaQuery.width * 0.042,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: mediaQuery.height * 0.02),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            crossAxisSpacing: mediaQuery.width * 0.03,
                            mainAxisSpacing: mediaQuery.height * 0.015,
                            // ✅ Responsive childAspectRatio
                            childAspectRatio:
                                mediaQuery.width / (mediaQuery.height * 0.28),
                            children: [
                              IconBottomSheet(
                                text: "Image",
                                icon: Icons.insert_photo,
                                backgroundColor: Colors.green,
                                onTap: () {
                                  Get.back();
                                  messagesPageController.pickMediaOrDocument(
                                    ImageSource.gallery,
                                    messagesPageController.profileWaKey,
                                    isImage: true,
                                  );
                                },
                              ),
                              IconBottomSheet(
                                text: "Video",
                                icon: Icons.videocam,
                                backgroundColor: Colors.pink,
                                onTap: () {
                                  Get.back();
                                  messagesPageController.pickMediaOrDocument(
                                    ImageSource.gallery,
                                    messagesPageController.profileWaKey,
                                    isVideo: true,
                                  );
                                },
                              ),
                              IconBottomSheet(
                                text: "Template",
                                icon: Icons.format_align_justify,
                                backgroundColor: Colors.blue,
                                onTap: () {
                                  showSendTemplateBottomSheet();
                                },
                              ),
                              IconBottomSheet(
                                text: "Document",
                                icon: Icons.insert_drive_file,
                                backgroundColor: Colors.grey,
                                onTap: () {
                                  Get.back();
                                  messagesPageController.pickMediaOrDocument(
                                    ImageSource.gallery,
                                    messagesPageController.profileWaKey,
                                    isDocument: true,
                                  );
                                },
                              ),
                              IconBottomSheet(
                                text: "Shortcut Message",
                                icon: Icons.flash_on,
                                backgroundColor: Colors.orange,
                                onTap: () {
                                  Get.back();
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () => ShortMessageSheet.show(
                                        messagesPageController),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: mediaQuery.height * 0.01),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.height * 0.15,
            ),
            child: TextField(
              controller: messagesPageController.textEditingController,
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              enableInteractiveSelection: true,
              selectionControls: MaterialTextSelectionControls(),
              toolbarOptions: const ToolbarOptions(
                copy: true,
                paste: true,
                cut: true,
                selectAll: true,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message here....',
                hintStyle: const TextStyle(color: AppTheme.black54),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: const BorderSide(color: AppTheme.greyColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7.0),
                  borderSide: const BorderSide(color: AppTheme.greyColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide(color: AppTheme.boarderColor),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: () {
            messagesPageController
                .sendMessage(messagesPageController.profileWaKey);
          },
        ),
      ],
    ),
  );
}
 
// ============================================================
// IconBottomSheet — Fully Responsive
// ============================================================
class IconBottomSheet extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;
 
  const IconBottomSheet({
    super.key,
    required this.text,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
 
    return InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(8),
  child: FittedBox(        // ✅ ADD FittedBox
    fit: BoxFit.scaleDown,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: w * 0.07,
          backgroundColor: backgroundColor,
          child: Icon(icon, size: w * 0.06, color: Colors.white),
        ),
        SizedBox(height: h * 0.008),
        Text(
          text,
          style: TextStyle(
            fontSize: w * 0.032,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  ),
);
  }
}
void _showCallOptionsBottomSheet(BuildContext context, String phoneNumber) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Text(
            'Call Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // WhatsApp Voice Call Option
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call, color: Colors.green, size: 24),
            ),
            title: const Text(
              'WhatsApp Voice Call',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(phoneNumber),
            onTap: () async {
              Get.back(); // Close bottom sheet
              await WhatsAppCallingConfig.openCallingScreenWithGetX(
                  phoneNumber);
            },
          ),

          const Divider(height: 30),

          // Regular Phone Call (Fallback)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.blue, size: 24),
            ),
            title: const Text(
              'Regular Call',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Use phone dialer'),
            onTap: () {
              Get.back();
              // Your existing dial pad functionality
              var messagesPageController = Get.find<MessagesPageController>();
              messagesPageController.openDialPad(url: 'tel:$phoneNumber');
            },
          ),

          const SizedBox(height: 10),
        ],
      ),
    ),
    backgroundColor: Colors.transparent,
  );
}
// }

// Widget _buildInputField() {
//   return Container(
//     padding: EdgeInsets.symmetric(horizontal: 8),
//     color: Colors.white,
//     child: Row(
//       children: [
//         IconButton(
//           icon: const Icon(Icons.add_circle),
//           onPressed: () {},
//         ),
//         Expanded(
//           child: TextField(
//             decoration: InputDecoration(
//               hintText: 'Type a message here....',
//               hintStyle: const TextStyle(color: AppTheme.black54),
//               filled: true,
//               fillColor: Colors.white,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(20.0),
//                 borderSide: const BorderSide(
//                   color: AppTheme.greyColor,
//                 ),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(7.0),
//                 borderSide: const BorderSide(
//                   color: AppTheme.greyColor,
//                 ),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(20.0),
//                 borderSide: const BorderSide(
//                   color: AppTheme.boarderColor,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.send),
//           onPressed: () {},
//         ),
//       ],
//     ),
//   );
// }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
// import 'package:getgabs/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart';
// import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
// import 'package:getgabs/ui/res/assets/image_assets.dart';
// import 'package:getgabs/ui/themes/themes.dart';
// import '../../../../../data/models/active_chat_model.dart';
// import '../../../../../data/models/message_modal.dart';
// import '../../../chat_uis/image_message_ui/image_message_ui.dart';
// import '../../../chat_uis/text_message_ui.dart';

// class MessagesPage extends StatelessWidget {
//   final Profile profile;
//   final String profileWaKey;
//   MessagesPage({super.key, required this.profile, required this.profileWaKey});

//   @override
//   Widget build(BuildContext context) {
//     var mediaQuery = MediaQuery.of(context).size;
//     final MessagesPageController messagesPageController =
//         Get.put(MessagesPageController(profileWaKey));

//     return Scaffold(
//       backgroundColor: AppTheme.whiteColor,
//       appBar: AppBar(
//         elevation: 4,
//         shadowColor: AppTheme.black54,
//         backgroundColor: AppTheme.whiteColor,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Get.back();
//             messagesPageController.currentPage.value = 1;
//           },
//         ),
//         title: Row(
//           children: [
//             const CircleAvatar(
//               backgroundImage: AssetImage(ImageAssets.profileImage),
//             ),
//             SizedBox(width: mediaQuery.width * 0.025),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     profile.profileName,
//                     style: TextStyle(fontSize: 16),
//                     overflow: TextOverflow.ellipsis,
//                     maxLines: 1,
//                   ),
//                   Text(profile.profileWaId.toString(),
//                       style: TextStyle(fontSize: 12)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
//           IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_sharp))
//         ],
//       ),
//       body: Column(children: [
//         // Date header at the top
//         // Obx(() {
//         //   var messageList = messagesPageController.messageChatList;
//         //   if (messageList.isNotEmpty) {
//         //     var latestMessageDate = messageList.first.createdAt.toString().split(' ')[0];
//         //     return Padding(
//         //       padding: const EdgeInsets.all(8.0),
//         //       child: Text(
//         //         latestMessageDate,
//         //         style: TextStyle(
//         //             color: Colors.grey,
//         //             fontWeight: FontWeight.bold,
//         //             fontSize: 14),
//         //       ),
//         //     );
//         //   } else {
//         //     return Container();
//         //   }
//         // }),
//         Expanded(
//           child: Obx(() {
//             if (messagesPageController.messageChatList.isNotEmpty) {

//               return ListView.builder(
//                 reverse: true,
//                 itemCount: messagesPageController.groupedMessages.keys.length,
//                 controller: messagesPageController.scrollController,
//                 itemBuilder: (context, index) {
//                   String date = messagesPageController.groupedMessages.keys
//                       .toList()[index];
//                   List<Message> messages =
//                       messagesPageController.groupedMessages[date]!;
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Align(
//                         alignment: Alignment.center,
//                         child: Container(
//                           margin: EdgeInsets.symmetric(vertical: 8),
//                           padding:
//                               EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [Colors.grey.shade300, Colors.grey],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             borderRadius: BorderRadius.circular(10),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.grey.shade500,
//                                 offset: Offset(0, 2),
//                                 blurRadius: 4,
//                               ),
//                             ],
//                           ),
//                           child: Text(
//                             date,
//                             style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 14),
//                           ),
//                         ),
//                       ),
//                       ...messages.map((message) {
//                         return buildMessageWidget(message, mediaQuery);
//                       }).toList(),
//                     ],
//                   );
//                 },
//               );
//             } else {
//               return Text("");
//             }
//           }),
//         ),
//         const Divider(),
//         _buildInputField(messagesPageController),
//         SizedBox(
//           height: mediaQuery.height * 0.01,
//         )
//       ]),
//     );
//   }

//   Widget buildMessageWidget(Message message, Size mediaQuery) {
//     if (message.messageType == 'text') {
//       return TextMessageUi(
//         text: message.messageText,
//         isSentByMe: message.sender == 1 ? false : true,
//         createdAt: message.createdAt,
//         mediaQuery: mediaQuery,
//       );
//     } else if (message.messageType == 'template') {
//       return TempleteMessageUi(
//         templateData: message.templateData!,
//         messageText: message.messageText,
//         isSentByMe: message.sender == 1 ? false : true,
//         createdAt: message.createdAt,
//         mediaQuery: mediaQuery,
//       );
//     } else if (message.messageType == 'image') {
//       return ImageMessageUi(
//         imageUrl:
//             "https://app.getgabs.com/customers/mediafile/${message.messageText}",
//         isSentByMe: true,
//         createdAt: message.createdAt,
//         mediaQuery: mediaQuery,
//         rightMargin: 10.0,
//         leftMargin: 10.0,
//       );
//     } else if (message.messageType == 'video') {
//       return VideoMessageUi(
//         videoUrl:
//             'https://app.getgabs.com/customers/mediafile/${message.messageText}',
//         isSentByMe: true,
//         createdAt: message.createdAt,
//         mediaQuery: mediaQuery,
//         rightMargin: 0,
//         leftMargin: mediaQuery.height * 0.06,
//         isInTemplate: false,
//       );
//     } else {
//       return Container();
//     }
//   }

//   Widget _buildInputField(MessagesPageController messagesPageController) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8),
//       color: Colors.white,
//       child: Row(
//         children: [
//           IconButton(
//             icon: const Icon(Icons.add_circle),
//             onPressed: () {},
//           ),
//           Expanded(
//             child: TextField(
//               controller: messagesPageController.textEditingController,
//               decoration: InputDecoration(
//                 hintText: 'Type a message here....',
//                 hintStyle: const TextStyle(color: AppTheme.black54),
//                 filled: true,
//                 fillColor: Colors.white,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.greyColor,
//                   ),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(7.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.greyColor,
//                   ),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.boarderColor,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.send),
//             onPressed: messagesPageController.sendMessage,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputField(MessagesPageController messagesPageController) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8),
//       color: Colors.white,
//       child: Row(
//         children: [
//           IconButton(
//             icon: const Icon(Icons.add_circle),
//             onPressed: () {},
//           ),
//           Expanded(
//             child: TextField(
//               controller: messagesPageController.textEditingController,
//               decoration: InputDecoration(
//                 hintText: 'Type a message here....',
//                 hintStyle: const TextStyle(color: AppTheme.black54),
//                 filled: true,
//                 fillColor: Colors.white,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.greyColor,
//                   ),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(7.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.greyColor,
//                   ),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.boarderColor,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.send),
//             onPressed: messagesPageController.sendMessage,
//           ),
//         ],
//       ),
//     );
// }
// Widget _buildInputField() {
//   return Container(
//     padding: EdgeInsets.symmetric(horizontal: 8),
//     color: Colors.white,
//     child: Row(
//       children: [
//         IconButton(
//           icon: const Icon(Icons.add_circle),
//           onPressed: () {},
//         ),
//         Expanded(
//           child: TextField(
//             decoration: InputDecoration(
//               hintText: 'Type a message here....',
//               hintStyle: const TextStyle(color: AppTheme.black54),
//               filled: true,
//               fillColor: Colors.white,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(20.0),
//                 borderSide: const BorderSide(
//                   color: AppTheme.greyColor,
//                 ),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(7.0),
//                 borderSide: const BorderSide(
//                   color: AppTheme.greyColor,
//                 ),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(20.0),
//                 borderSide: const BorderSide(
//                   color: AppTheme.boarderColor,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.send),
//           onPressed: () {},
//         ),
//       ],
//     ),
//   );
// }

//------------------------------------------------------------------------------------------------------------
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
// import 'package:getgabs/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart';
// import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
// import 'package:getgabs/ui/res/assets/image_assets.dart';
// import 'package:getgabs/ui/themes/themes.dart';
// import '../../../../../data/models/active_chat_model.dart';
// import '../../../chat_uis/image_message_ui/image_message_ui.dart';
// import '../../../chat_uis/text_message_ui.dart';

// class MessagesPage extends StatelessWidget {
//   final Profile profile;
//   final String profileWaKey;
//   MessagesPage({super.key, required this.profile, required this.profileWaKey});

//   @override
//   Widget build(BuildContext context) {
//     var mediaQuery = MediaQuery.of(context).size;
//     final MessagesPageController messagesPageController =
//         Get.put(MessagesPageController(profileWaKey));

//     return Scaffold(
//       backgroundColor: AppTheme.whiteColor,
//       appBar: AppBar(
//         elevation: 4,
//         shadowColor: AppTheme.black54,
//         backgroundColor: AppTheme.whiteColor,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Get.back();
//             // dashboardController.messageChatList.clear();
//             messagesPageController.currentPage.value = 1;
//           },
//         ),
//         title: Row(
//           children: [
//             const CircleAvatar(
//               backgroundImage: AssetImage(ImageAssets.profileImage),
//             ),
//             SizedBox(width: mediaQuery.width * 0.025),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     profile.profileName,
//                     style: TextStyle(fontSize: 16),
//                     overflow: TextOverflow.ellipsis,
//                     maxLines: 1,
//                   ),
//                   Text(profile.profileWaId.toString(),
//                       style: TextStyle(fontSize: 12)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
//           IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_sharp))
//         ],
//       ),
//       body: Column(children: [
//         Expanded(
//           child: Obx(() {
//             debugPrint('slkdfjklsdjfkjsdafsadl;kjflk;asjdflkjasd;lfjdl;sa');
//             debugPrint(messagesPageController.messageChatList);
//             if (messagesPageController.messageChatList.isNotEmpty) {
//               return ListView.builder(
//                 reverse: true,
//                 itemCount: messagesPageController.messageChatList.length,
//                 controller:messagesPageController. scrollController,
//                 itemBuilder: (context, index) {
//                   final messages =
//                       messagesPageController.messageChatList[index];

//                   return Column(
//                     children: [
//                       // const Divider(
//                       //   color: AppTheme.boarderColor,
//                       // ),
//                       if (messages.messageType == 'text')
//                         TextMessageUi(
//                           text: messages.messageText,
//                           isSentByMe: messages.sender == 1 ? false : true,
//                           createdAt: messages.createdAt,
//                           mediaQuery: mediaQuery,
//                         ),
//                       if (messages.messageType == 'template')
//                         TempleteMessageUi(
//                           templateData: messages.templateData!,
//                           messageText: messages.messageText,
//                           isSentByMe: messages.sender == 1 ? false : true,
//                           createdAt: messages.createdAt,
//                           mediaQuery: MediaQuery.of(context).size,
//                         ),

//                       // TempleteMessageUi(
//                       //   headerText: headerText,
//                       //   bodyText: bodyText,
//                       //   footerText: footerText,
//                       //   // messageType: messages.messageType,
//                       //   isSentByMe: messages.sender == 1 ? false : true,
//                       //   createdAt: messages.createdAt,
//                       //   mediaQuery: MediaQuery.of(context).size,
//                       // ),
//                       if (messages.messageType == 'image')
//                         ImageMessageUi(
//                           imageUrl:
//                               "https://app.getgabs.com/customers/mediafile/${messages.messageText}",
//                           isSentByMe: true,
//                           createdAt: messages.createdAt,
//                           mediaQuery: MediaQuery.of(context).size,
//                           rightMargin: 10.0,
//                           leftMargin: 10.0,
//                         ),

//                       if (messages.messageType == 'video')
//                         VideoMessageUi(
//                           videoUrl:
//                               'https://app.getgabs.com/customers/mediafile/${messages.messageText}',
//                           isSentByMe: true,
//                           createdAt: messages.createdAt,
//                           mediaQuery: mediaQuery,
//                           rightMargin: 0,
//                           leftMargin: mediaQuery.height * 0.06,
//                           isInTemplate: false,
//                         ),
//                     ],
//                   );
//                 },
//               );
//             } else {
//               return Text("");
//             }
//           }),
//         ),
//         const Divider(),
//         // SizedBox(
//         //   height: mediaQuery.height * 0.001,
//         // ),
//         _buildInputField(messagesPageController),
//         SizedBox(
//           height: mediaQuery.height * 0.01,
//         )
//       ]),
//     );
//   }
//   Widget _buildInputField(MessagesPageController messagesPageController) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8),
//       color: Colors.white,
//       child: Row(
//         children: [
//           IconButton(
//             icon: const Icon(Icons.add_circle),
//             onPressed: () {},
//           ),
//           Expanded(
//             child: TextField(
//               controller: messagesPageController.textEditingController,
//               decoration: InputDecoration(
//                 hintText: 'Type a message here....',
//                 hintStyle: const TextStyle(color: AppTheme.black54),
//                 filled: true,
//                 fillColor: Colors.white,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.greyColor,
//                   ),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(7.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.greyColor,
//                   ),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: const BorderSide(
//                     color: AppTheme.boarderColor,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.send),
//             onPressed: messagesPageController.sendMessage,
//           ),
//         ],
//       ),
//     );
// }

//   // Widget _buildInputField() {
//   //   return Container(
//   //     padding:  EdgeInsets.symmetric(horizontal: 8),
//   //     color: Colors.white,
//   //     child: Row(
//   //       children: [
//   //         IconButton(
//   //           icon: const Icon(Icons.add_circle),
//   //           onPressed: () {},
//   //         ),
//   //         Expanded(
//   //           child: TextField(
//   //             // decoration: InputDecoration(
//   //             //   hintText: 'Type a message here...',
//   //             //   border: InputBorder.none,
//   //             // ),
//   //             decoration: InputDecoration(
//   //               hintText: 'Type a message here....',
//   //               hintStyle: const TextStyle(color: AppTheme.black54),
//   //               filled: true,
//   //               fillColor: Colors.white,
//   //               border: OutlineInputBorder(
//   //                 borderRadius: BorderRadius.circular(20.0),
//   //                 borderSide: const BorderSide(
//   //                   color: AppTheme.greyColor,
//   //                 ),
//   //               ),
//   //               enabledBorder: OutlineInputBorder(
//   //                 borderRadius: BorderRadius.circular(7.0),
//   //                 borderSide: const BorderSide(
//   //                   color: AppTheme.greyColor,
//   //                 ),
//   //               ),
//   //               focusedBorder: OutlineInputBorder(
//   //                 borderRadius: BorderRadius.circular(20.0),
//   //                 borderSide: const BorderSide(
//   //                   color: AppTheme.boarderColor,
//   //                 ),
//   //               ),
//   //             ),
//   //           ),
//   //         ),
//   //         IconButton(
//   //           icon: const Icon(Icons.send),
//   //           onPressed: () {},
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
// }
