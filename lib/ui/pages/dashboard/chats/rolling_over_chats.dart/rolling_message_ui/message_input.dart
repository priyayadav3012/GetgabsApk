import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/models/active_chat_model.dart';
import 'package:getgabs/data/models/rolling_over_chat_model.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:getgabs/ui/pages/chat_uis/image_message_ui/image_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/text_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/assign_to_teammate_dialog.dart';
import 'package:getgabs/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_message_ui/send_template.dart';
import 'package:getgabs/ui/themes/themes.dart';

import '../../../../../../data/models/message_modal.dart';
import '../../../../chat_uis/audio_message_ui/audio_message_ui.dart';
import '../../../../chat_uis/base_message_ui.dart';
import '../../../../chat_uis/button_message_ui.dart';
import '../../../../chat_uis/call_message_ui/call_message_ui.dart';
import '../../../../chat_uis/document_message/document_message_ui.dart';
import '../../../../chat_uis/location_message_ui/location_message_ui.dart';
import '../../../../chat_uis/note_message_ui/note_message_ui.dart';
import '../../../../chat_uis/order_message/order_message_ui.dart';
import '../../../../chat_uis/reply_message/reply_message_ui.dart';

class MessageRollingPage extends StatelessWidget {
  // final RollingOverChatModel rollingOverChatModel;
  final Profile rollingOverChatModel;
  final String profileWaKey;
  final int profileWaId;
  final int getPendingMsgCount;

  const MessageRollingPage({
    super.key,
    required this.rollingOverChatModel,
    required this.profileWaKey,
    required this.profileWaId,
    required this.getPendingMsgCount,
  });

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    final MessagesPageController messagesPageController = Get.put(
        MessagesPageController(
            profileWaKey, profileWaId, 'inactive', rollingOverChatModel));
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
            // dashboardController.messageChatList.clear();
            messagesPageController.currentPage.value = 1;
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                'https://ui-avatars.com/api/?name=${messagesPageController.replaceFirstTwoSpaces(rollingOverChatModel.profileName)}',
              ),
            ),
            SizedBox(width: mediaQuery.width * 0.025),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rollingOverChatModel.profileName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(rollingOverChatModel.profileWaId.toString(),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {
                messagesPageController.openDialPad(
                    url: 'tel: ${rollingOverChatModel.profileWaId}');
              },
              icon: const Icon(Icons.call)),
          IconButton(
            onPressed: () {
              showAssignToTeammateDialog(
                customerKey: profileWaKey,
                customerName: rollingOverChatModel.profileName,
                customerPhone: rollingOverChatModel.profileWaId.toString(),
                messagesPageController: messagesPageController,
                isAlreadyAssignedToAgent:
                    rollingOverChatModel.assignedUserId != null,
                currentAssignedAgentId: rollingOverChatModel.assignedUserId,
              );
            },
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Assign Chat',
          ),
        ],
//         actions: [
//           IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
//            PopupMenuButton<String>(
//     icon: const Icon(Icons.more_vert_sharp),
//     onSelected: (value) {
//        if (value == 'Assign Chat') {
//        Get.toNamed(AppRoute.assignOpreator);
//       }else if (value == 'Add Tags') {
//   showAddTagsBottomSheet();
// }
// else if (value == 'Block') {
//         showAddTagsBottomSheet();
//       }
//       else if (value == 'Export Chat') {
//        showAddTagsBottomSheet();
//       }
//       else if (value == 'Add to Favorite') {
//         // Get.to(SuggestScreen());
//       }
//     },
//     itemBuilder: (BuildContext context) {
//       return [
//         PopupMenuItem<String>(
//           value: 'Assign Chat',
//           child: Text('Assign Chat',style: TextStyle(fontWeight: FontWeight.w400),),
//         ),
//         PopupMenuItem<String>(
//           value: 'Add Tags',
//           child: Text('Add Tags',style: TextStyle(fontWeight: FontWeight.w400),),
//         ),
//          PopupMenuItem<String>(
//           value: 'Block',
//           child: Text('Block',style: TextStyle(fontWeight: FontWeight.w400),),
//         ),
//          PopupMenuItem<String>(
//           value: 'Export Chat',
//           child: Text('Export Chat',style: TextStyle(fontWeight: FontWeight.w400),),
//         ),
//          PopupMenuItem<String>(
//           value: 'Add to Favorite',
//           child: Text('Add to Favorite',style: TextStyle(fontWeight: FontWeight.w400),),
//         ),
//       ];
//     },
//     offset: const Offset(0, 12),
//     position: PopupMenuPosition.under,
//   ),
//         ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Obx(() {
              if (messagesPageController.groupedMessages.isNotEmpty) {
                return ListView.builder(
                  reverse: true,
                  itemCount: messagesPageController.groupedMessages.keys.length,
                  controller: messagesPageController.scrollController,
                  itemBuilder: (context, index) {
                    String date = messagesPageController.groupedMessages.keys
                        .toList()[index];
                    List<Message> messages =
                        messagesPageController.groupedMessages[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            // decoration: BoxDecoration(
                            //   gradient: LinearGradient(
                            //     colors: [Colors.grey.shade300, Colors.grey],
                            //     begin: Alignment.topLeft,
                            //     end: Alignment.bottomRight,
                            //   ),
                            //   borderRadius: BorderRadius.circular(10),
                            //   boxShadow: [
                            //     BoxShadow(
                            //       color: Colors.grey.shade500,
                            //       offset: const Offset(0, 2),
                            //       blurRadius: 4,
                            //     ),
                            //   ],
                            // ),
                            child: Text(
                              date,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                        ...messages.map((message) {
                          final controller = Get.find<MessagesPageController>();
                          return Obx(() {
                            final isHighlighted =
                                controller.highlightedMessageId.value ==
                                    message.messageId;
                            return Container(
                              key: controller.keyForMessage(message.messageId),
                              color: isHighlighted
                                  ? const Color(0xFFD3E3FD)
                                  : Colors.transparent,
                              child: buildMessageWidget(
                                  message, mediaQuery, rollingOverChatModel),
                            );
                          });
                        }),
                      ],
                    );
                  },
                );
              } else {
                return const Text("");
              }
            }),
          ),
          const Divider(),
          _buildInputField(profileWaKey, mediaQuery),
          SizedBox(
            height: mediaQuery.height * 0.01,
          )
        ]),
      ),
    );
  }

  Widget buildMessageWidget(Message message, Size mediaQuery, dynamic profile) {
    if (message.messageType == 'text') {
      return TextMessageUi(
        text: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    } else if (message.messageType == 'template') {
      return TempleteMessageUi(
        templateData: message.templateData,
        messageText: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        messageType: message.messageType,
        senderName: null, // 👈 pass sender name
      );
    } else if (message.messageType == 'image') {
      return ImageMessageUi(
        imageFile: message.local ? File(message.messageText) : null,
        imageUrl: message.mediaUrl,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 10.0,
        leftMargin: 10.0,
        deliveryStatus: message.deliveryStatus ?? "sent",
        caption: message.captionText == null ? "" : message.captionText!,
      );
    } else if (message.messageType == 'audio') {
      return AudioMessageUi(
        audioUrl: message.mediaUrl,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        rightMargin: 0,
        leftMargin: 0,
        isInTemplate: false,
        // isLocal: message.local,
        deliveryStatus: message.deliveryStatus ?? "sent",
      );
    }else if (message.messageType == 'video') {
      return VideoMessageUi(
        videoUrl: message.mediaUrl,
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
        documentFile: message.mediaUrl,
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
    }

    // else if (message.messageType == 'reply_msg') {
    //   final messageData = jsonDecode(message.messageText);

    //   final replyText = messageData['text']?['body'] ?? "No reply text";

    //   return ReplyMessageUi(
    //     replyText: replyText,
    //     isSentByMe: message.sender == 1 ? false : true,
    //     createdAt: message.createdAt,
    //     mediaQuery: mediaQuery,
    //     deliveryStatus: message.deliveryStatus ?? "sent",
    //     replyFormData: message.replyformsg!,
    //   );
    // }

    else if (message.messageType == 'interactive' &&
        message.hasCallHistory) {
      return CallMessageUi(
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        callDurationSeconds: message.callDurationSeconds,
        callStatus: message.callStatus,
        direction: message.direction,
        callConnectedAt: message.callConnectedAt,
      );
    }
    else if (message.messageType == 'buttons' ||
        message.messageType == 'interactive') {
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
        // The app's own replies carry text.body; a reply sent from the web
        // app instead carries a flat {content_send_type, msgcontent,
        // message_id} shape with the reply text under msgcontent and no
        // replyformsg (no quoted-message data) — fall back to that instead
        // of showing "No reply text" for every web-originated reply.
        var replyText = messageData['text']?['body'] ??
            messageData['msgcontent'] ??
            "No reply text";

        // replyformsg (the quoted-preview snapshot) only exists on the
        // LOCAL optimistic message right after sending — a reload from
        // history doesn't carry it back (the server's reply_to block isn't
        // in the fetchcustomerchat list response, only in sendReplyChat's
        // own immediate response). Fall back to looking the original
        // message up by id in the currently-loaded chat, so the quoted box
        // still shows after leaving and reopening the chat.
        String replyFormData = message.replyformsg ?? '';
        final quotedMessageId = messageData['message_id']?.toString();
        final controller = Get.find<MessagesPageController>();
        if (replyFormData.isEmpty) {
          if (quotedMessageId != null && quotedMessageId.isNotEmpty) {
            final chatList = controller.messageChatList;
            final index =
                chatList.indexWhere((m) => m.messageId == quotedMessageId);
            if (index != -1) {
              final quoted = chatList[index];
              replyFormData = jsonEncode({
                'message_id': quoted.messageId,
                'message_type': quoted.messageType,
                'message_text': quoted.messageText,
                'template_data': quoted.templateData,
                'local': quoted.local,
                'quoted_sender_name': controller.resolveQuotedSenderName(quoted),
              });
            } else {
              // Not in the currently-loaded pages (common for notes/early
              // templates, which tend to be older) — quietly load a few
              // more pages in the background; once found, the reactive
              // rebuild picks it up without the user needing to scroll.
              controller.ensureMessageLoaded(quotedMessageId);
            }
          }
        }

        return ReplyMessageUi(
          replyText: replyText,
          isSentByMe: message.sender == 1 ? false : true,
          createdAt: message.createdAt,
          mediaQuery: mediaQuery,
          deliveryStatus: message.deliveryStatus ?? "sent",
          replyFormData: replyFormData,
          onTapQuoted: (id) => controller.scrollToMessage(id),
          unresolvedQuotedMessageId:
              replyFormData.isEmpty ? quotedMessageId : null,
          onRetryLoadQuoted: (id) =>
              controller.ensureMessageLoaded(id, forceRetry: true),
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
    } else if (message.messageType == 'note') {
      return NoteMessageUi(message: message, mediaQuery: mediaQuery);
    } else {
      return BaseMessageUi(
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SizedBox(height: 5), SelectableText('')],
        ),
      );
    }

    // else {
    //   return Container();
    // }
  }

  bool isJson(String str) {
    try {
      jsonDecode(str); // Try to decode
      return true;
    } catch (e) {
      return false; // Return false if decoding fails
    }
  }

  /*    body: Column(children: [
        Expanded(
          child: Obx(() {
            print('slkdfjklsdjfkjsdafsadl;kjflk;asjdflkjasd;lfjdl;sa');
            print(messagesPageController.messageChatList);
            if (messagesPageController.messageChatList.isNotEmpty) {
              return ListView.builder(
                reverse: true,
                itemCount: messagesPageController.messageChatList.length,
                controller: messagesPageController.scrollController,
                itemBuilder: (context, index) {
                  final messages =
                      messagesPageController.messageChatList[index];
                  String deliveryStatus =
                      messages.deliveryStatus ?? "delivered";
                  return Column(
                    children: [
                      // const Divider(
                      //   color: AppTheme.boarderColor,
                      // ),
                      if (messages.messageType == 'text')
                        Padding(
                          padding:
                              EdgeInsets.only(top: mediaQuery.height * 0.05),
                          child: TextMessageUi(
                            text: messages.messageText,
                            isSentByMe: messages.sender == 1 ? false : true,
                            createdAt: messages.createdAt,
                            mediaQuery: mediaQuery,
                            deliveryStatus: deliveryStatus,
                          ),
                        ),
                      if (messages.messageType == 'template')
                        Padding(
                          padding:
                              EdgeInsets.only(top: mediaQuery.height * 0.05),
                          child: TempleteMessageUi(
                            templateData: messages.templateData!,
                            messageText: messages.messageText,
                            isSentByMe: messages.sender == 1 ? false : true,
                            createdAt: messages.createdAt,
                            mediaQuery: MediaQuery.of(context).size,
                            deliveryStatus: deliveryStatus,
                          ),
                        ),

                      if (messages.messageType == 'image')
                        ImageMessageUi(
                          imageUrl: messages.mediaUrl,
                          isSentByMe: true,
                          createdAt: messages.createdAt,
                          mediaQuery: MediaQuery.of(context).size,
                          rightMargin: 10.0,
                          leftMargin: 10.0,
                          deliveryStatus: deliveryStatus,
                        ),

                      if (messages.messageType == 'video')
                        VideoMessageUi(
                          videoUrl: messages.mediaUrl,
                          isSentByMe: true,
                          createdAt: messages.createdAt,
                          mediaQuery: mediaQuery,
                          rightMargin: 0,
                          leftMargin: mediaQuery.height * 0.06,
                          isInTemplate: false,
                          deliveryStatus: deliveryStatus,
                        ),
                    ],
                  );
                },
              );
            } else {
              return Text("");
            }
          }),
        ),
        const Divider(),
        // SizedBox(
        //   height: mediaQuery.height * 0.001,
        // ),
        _buildInputField(messagesPageController, profileWaKey),
        SizedBox(
          height: mediaQuery.height * 0.01,
        )
      ]),
    );
  }
}
*/
  Widget _buildInputField(var messagesPageController, var profileWaKey) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: Colors.grey,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Session Expired",
                      style: TextStyle(
                          color: AppTheme.customRed,
                          fontWeight: FontWeight.w400,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 17),
                  ElevatedButton(
                    onPressed: () {
                      // var messageText =
                      //     "{\n  \"to\": \"917974758902\",\n  \"type\": \"template\",\n  \"template\": {\n    \"name\": \"hello_world\",\n    \"language\": {\n      \"code\": \"en_US\"\n    }\n  },\n  \"recipient_type\": \"individual\",\n  \"messaging_product\": \"whatsapp\"\n}";
                      // var template =
                      //     "{\"data\": [{\"id\": \"755512876566597\", \"name\": \"hello_world\", \"status\": \"APPROVED\", \"category\": \"UTILITY\", \"language\": \"en_US\", \"components\": [{\"text\": \"Hello World\", \"type\": \"HEADER\", \"format\": \"TEXT\"}, {\"text\": \"Welcome and congratulations!! This message demonstrates your ability to send a WhatsApp message notification from the Cloud API, hosted by Meta. Thank you for taking the time to test with us.\", \"type\": \"BODY\"}, {\"text\": \"WhatsApp Business Platform sample message\", \"type\": \"FOOTER\"}]}], \"paging\": {\"cursors\": {\"after\": \"MjQZD\", \"before\": \"MAZDZD\"}}}";

                      // messagesPageController.sendHelloWorldMessageTemplate(
                      //     profileWaKey, messageText, template);
                      showSendTemplateBottomSheet();
                      // BottomSheetWidget();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.customOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      minimumSize: const Size(240, 35),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7.0, vertical: 12.0),
                    ),
                    child: const Text(
                      'Send Template Message',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
