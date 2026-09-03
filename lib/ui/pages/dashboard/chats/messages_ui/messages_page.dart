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
import 'package:getgabs/ui/pages/chat_uis/swipe_to_reply_wrapper.dart';
import 'package:getgabs/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
import 'package:getgabs/ui/pages/dashboard/chats/active_chats/active_chat_list_tile.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/customer_profile_dialog.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/shortmessagesheet.dart';
import 'package:getgabs/ui/res/widgets/skeleton_loaders.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../data/models/active_chat_model.dart';
import '../../../../../data/models/message_modal.dart';
import '../../../chat_uis/audio_message_ui/audio_message_ui.dart';
import '../../../chat_uis/base_message_ui.dart';
import '../../../chat_uis/button_message_ui.dart';
import '../../../chat_uis/call_message_ui/call_message_ui.dart';
import '../../../chat_uis/document_message/document_message_ui.dart';
import '../../../chat_uis/image_message_ui/image_message_ui.dart';
import '../../../chat_uis/location_message_ui/location_message_ui.dart';
import '../../../chat_uis/note_message_ui/note_message_ui.dart';
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
    // Reuse the existing controller when this same chat is rebuilt (keyboard
    // open, orientation, parent rebuild, etc.) instead of creating a brand-new
    // one — a fresh Get.put on every build re-ran onInit (refetching chats and
    // re-marking read) and churned the open-chat registration. A different
    // profileWaKey means we navigated to another conversation, so create fresh.
    final bool sameChatAlreadyOpen =
        Get.isRegistered<MessagesPageController>() &&
            Get.find<MessagesPageController>().profileWaKey == profileWaKey;
    final MessagesPageController messagesPageController = sameChatAlreadyOpen
        ? Get.find<MessagesPageController>()
        : Get.put(MessagesPageController(
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
        title: Obx(() {
          // Same colored-initials style as the chat list avatar, instead of
          // a ui-avatars.com network image (which showed as plain grey while
          // loading/on failure since CircleAvatar has no fallback color).
          final safeName =
              cleanName(messagesPageController.userProfile.value.profileName);
          return InkWell(
            onTap: () => showCustomerProfileDialog(messagesPageController),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: getAvatarBgColor(safeDecode(safeName)),
                  child: Text(
                    getInitialsSafe(safeName),
                    style: TextStyle(
                      color: getAvatarTextColor(safeDecode(safeName)),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                      Obx(() => Text(
                            messagesPageController.isOtherPartyTyping.value
                                ? 'typing…'
                                : messagesPageController
                                    .userProfile.value.profileWaId
                                    .toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: messagesPageController
                                      .isOtherPartyTyping.value
                                  ? const Color(0xFF00A884)
                                  : null,
                              fontStyle: messagesPageController
                                      .isOtherPartyTyping.value
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        actions: [
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
                child: Stack(
                  children: [
                    Obx(() {
                  if (messagesPageController.isInitialChatLoading.value) {
                    return const MessagesSkeleton();
                  }

                  if (messagesPageController.groupedMessages.isEmpty) {
                    return const SizedBox();
                  }

                  return ListView.builder(
                    reverse: true,
                    // The reaction badge on a message bubble overflows a
                    // few px below the bubble itself (see _wrapWithReaction)
                    // — without room to render into, the newest message
                    // (bottom-most in this reversed list, right against the
                    // composer) had its badge clipped by the list's own
                    // edge. Padding both sides since reverse:true swaps
                    // which EdgeInsets side lands at the visual bottom.
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                            (message) => Obx(() {
                              final isHighlighted = messagesPageController
                                      .highlightedMessageId.value ==
                                  message.messageId;
                              return Container(
                                key: messagesPageController
                                    .keyForMessage(message.messageId),
                                color: isHighlighted
                                    ? const Color(0xFFD3E3FD)
                                    : Colors.transparent,
                                child: message.messageType == 'note'
                                    // Notes are internal team/assignment
                                    // notes, not real WhatsApp messages in
                                    // the thread — replying to one doesn't
                                    // make sense (sendReplyChat quotes an
                                    // actual conversation message), so skip
                                    // the swipe-to-reply gesture entirely.
                                    ? _wrapWithSenderName(
                                        message,
                                        _wrapWithReaction(
                                          message,
                                          buildMessageWidget(
                                              message, mediaQuery),
                                        ),
                                        messagesPageController,
                                        mediaQuery,
                                      )
                                    : SwipeToReplyWrapper(
                                        onReply: () => messagesPageController
                                            .startReply(message),
                                        child: _wrapWithSenderName(
                                          message,
                                          _wrapWithReaction(
                                            message,
                                            buildMessageWidget(
                                                message, mediaQuery),
                                          ),
                                          messagesPageController,
                                          mediaQuery,
                                        ),
                                      ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  );
                }),
                    Obx(() {
                      if (!messagesPageController.showJumpToLatest.value) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 12,
                        bottom: 12,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: messagesPageController.jumpToLatestMessage,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.keyboard_double_arrow_down,
                                  color: Colors.black54, size: 22),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // const Divider(height: 1),

              /// ================= INPUT FIELD =================
              _buildInputField(
                messagesPageController,
                profileWaKey,
                mediaQuery,
                context,
              ),

              // Small breathing room below the composer — but only when the
              // SafeArea above isn't already reserving bottom space (e.g.
              // Android, where that inset is usually 0). On iPhones with a
              // home indicator, SafeArea already adds ~34px there; stacking
              // this fixed gap on top of it is what made the composer look
              // like it had an oversized white strip beneath it on iOS while
              // Android (near-zero inset) looked fine.
              if (MediaQuery.of(context).padding.bottom == 0)
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

  // Overlays a small WhatsApp-style emoji badge on the tail corner of an
  // already-built message bubble — bottom-right for a sent message, bottom-
  // left for a received one (mirrors BaseMessageUi's tail corner, the one
  // with borderRadius 0) — without needing every message-type widget to
  // thread a new parameter down into BaseMessageUi.
  Widget _wrapWithReaction(Message message, Widget bubble) {
    final emoji = message.reactionEmoji;
    if (emoji == null || emoji.isEmpty) return bubble;

    final isSentByMe = message.sender != 1;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          bottom: -8,
          right: isSentByMe ? 18 : null,
          left: isSentByMe ? null : 18,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1),
            ),
          ),
        ),
      ],
    );
  }

  // Shows who sent a sent bubble — WATI/Interakt-style attribution for a
  // shared inbox where multiple agents reply from the same WhatsApp number.
  // Resolution logic lives in MessagesPageController.resolveSenderDisplayName
  // (shared with the Team Note card's own header name).
  Widget _wrapWithSenderName(
    Message message,
    Widget bubble,
    MessagesPageController controller,
    Size mediaQuery,
  ) {
    // NoteMessageUi shows its own "who" attribution inline in its header —
    // don't also stack this label underneath it.
    if (message.messageType == 'note') return bubble;

    final name = controller.resolveSenderDisplayName(message);
    if (name == null || name.isEmpty) return bubble;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(right: 20, top: 2, bottom: 2),
          // Bounded to the same max width BaseMessageUi gives the bubble
          // itself, so a long name truncates with "…" instead of running
          // past the bubble's edge.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mediaQuery.width * 0.7),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
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
        text: displayText,
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
          isAutoreply: message.isAutoreply,
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
            isAutoreply: message.isAutoreply,
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
        caption: message.captionText == null
            ? "yyyyyyyyyyyyyyyyyyyyyyyyy"
            : message.captionText!,
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
    } else if (message.messageType == 'video') {
// loadThumbnailFromUrl('https://app.getgabs.com/customers/mediafile/${message.messageText}');
// return _buildThumbnailView('https://app.getgabs.com/customers/mediafile/${message.messageText}');
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
    } else if (message.messageType == 'interactive' && message.hasCallHistory) {
      // A voice-call-related "interactive" message (e.g. a call-permission
      // reply) that also carries callHistory data — show the call log UI
      // instead of the generic interactive-reply UI. Covers both call
      // directions (customer calling us, or us calling the customer).
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
    } else if (message.messageType == 'interactive' ||
        message.messageType == 'buttons') {
      return TempleteMessageUi(
        templateData: message.templateData,
        messageText: message.messageText,
        isSentByMe: message.sender == 1 ? false : true,
        createdAt: message.createdAt,
        mediaQuery: mediaQuery,
        deliveryStatus: message.deliveryStatus ?? "sent",
        messageType: message.messageType,
        senderName: profile.profileName,
        isAutoreply: message.isAutoreply,
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
      return NoteMessageUi(
        message: message,
        mediaQuery: mediaQuery,
        controller: Get.find<MessagesPageController>(),
      );
    } else {
      // Unrecognized messageType (e.g. an auto-generated/system message
      // whose type isn't one of the cases above) used to render as a
      // totally blank bubble. Fall back to showing the raw text/body
      // instead of dropping the content silently.
      String displayText = message.messageText;
      String? interactiveReplyTitle;
      String? contextId;
      try {
        final decoded = jsonDecode(message.messageText);
        if (decoded is Map) {
          final interactive = decoded['interactive'];
          final replyTitle = interactive is Map
              ? (interactive['list_reply']?['title']?.toString() ??
                  interactive['button_reply']?['title']?.toString() ??
                  interactive['nfm_reply']?['name']?.toString())
              : null;
          final body = decoded['text']?['body']?.toString() ??
              decoded['body']?.toString() ??
              decoded['caption']?.toString() ??
              replyTitle;
          if (body != null && body.isNotEmpty) displayText = body;
          if (replyTitle != null && replyTitle.isNotEmpty) {
            interactiveReplyTitle = replyTitle;
            contextId = decoded['context']?['id']?.toString();
          }
        }
      } catch (_) {}
      if (displayText.trim().isEmpty) {
        displayText = '[${message.messageType}]';
      }

      // A WhatsApp list/button reply — render it like a quoted WhatsApp
      // reply (a small preview of the message it replied to, followed by
      // the option the customer picked) instead of plain/raw text.
      if (interactiveReplyTitle != null) {
        String? quotedPreview;
        if (contextId != null && contextId.isNotEmpty) {
          final chatList = Get.find<MessagesPageController>().messageChatList;
          final originalIndex =
              chatList.indexWhere((m) => m.messageId == contextId);
          if (originalIndex != -1) {
            quotedPreview = _previewTextFor(chatList[originalIndex]);
          }
        }
        return BaseMessageUi(
          isSentByMe: message.sender == 1 ? false : true,
          createdAt: message.createdAt,
          mediaQuery: mediaQuery,
          deliveryStatus: message.deliveryStatus ?? "sent",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quotedPreview != null && quotedPreview.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(
                      left: BorderSide(color: Colors.green, width: 4.0),
                    ),
                  ),
                  child: Text(
                    quotedPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              SelectableText(
                interactiveReplyTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
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

  // Best-effort short preview of an arbitrary earlier message, used to show
  // "replied to" context above a WhatsApp list/button reply.
  String _previewTextFor(Message m) {
    String text = m.messageText;
    try {
      final decoded = jsonDecode(m.messageText);
      if (decoded is Map) {
        final body = decoded['text']?['body']?.toString() ??
            decoded['body']?.toString() ??
            decoded['caption']?.toString();
        if (body != null && body.isNotEmpty) text = body;
      }
    } catch (_) {}
    return text;
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

Widget _buildInputField(MessagesPageController messagesPageController,
    var profileWaKey, Size mediaQuery, BuildContext context) {
  void openAttachmentSheet() {
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
                            () =>
                                ShortMessageSheet.show(messagesPageController),
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
  }

  return Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Obx(() {
      final replyMsg = messagesPageController.replyingToMessage.value;
      if (replyMsg == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(10),
          border: const Border(
              left: BorderSide(color: Colors.green, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Replying to ${messagesPageController.resolveQuotedSenderName(replyMsg)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    replyMsg.previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: messagesPageController.cancelReply,
            ),
          ],
        ),
      );
    }),
  
      Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: Colors.white,
    child: Stack(
      children: [
        // Big rounded composer card — text starts at the top; extra bottom
        // padding (44) reserves room for the "+" / send circles sitting
        // inside its bottom corners, so growing text never runs under them.
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 72,
            maxHeight: mediaQuery.height * 0.25,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 44),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: messagesPageController.textEditingController,
            builder: (context, value, child) {
              return TextField(
                controller: messagesPageController.textEditingController,
                focusNode: messagesPageController.textFieldFocusNode,
                keyboardType: TextInputType.multiline,
                maxLines: 6,
                minLines: 1,
                enableInteractiveSelection: true,
                selectionControls: MaterialTextSelectionControls(),
                // Slash-command style shortcut: typing "/" as the very
                // first character (compose box was empty) opens the
                // shortcut messages sheet, same as picking it from the "+"
                // attachment menu. Clearing it here means the "/" never
                // lingers whether a shortcut gets picked or the sheet is
                // dismissed without choosing one.
                onChanged: (text) {
                  if (text == '/') {
                    messagesPageController.textEditingController.clear();
                    ShortMessageSheet.show(messagesPageController);
                  }
                  if (text.isNotEmpty) {
                    messagesPageController.notifyTyping();
                  }
                },
                toolbarOptions: const ToolbarOptions(
                  copy: true,
                  paste: true,
                  cut: true,
                  selectAll: true,
                ),
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Type a message here....',
                  hintStyle: const TextStyle(color: AppTheme.black54),
                  isCollapsed: true,
                  border: InputBorder.none,
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close,
                              color: AppTheme.black54, size: 20),
                          onPressed: () => messagesPageController
                              .textEditingController.clear(),
                        ),
                ),
              );
            },
          ),
        ),

        // "+" attachment button — inside the card's bottom-left corner.
        Positioned(
          left: 6,
          bottom: 6,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: openAttachmentSheet,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: Icon(Icons.add, color: Colors.black54, size: 16),
              ),
            ),
          ),
        ),

        // Send button — inside the card's bottom-right corner.
        Positioned(
          right: 6,
          bottom: 6,
          child: Material(
            color: AppTheme.authButtonColor,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                messagesPageController
                    .sendMessage(messagesPageController.profileWaKey);
              },
              child: const SizedBox(
                width: 30,
                height: 30,
                child: Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
  ],
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
      child: FittedBox(
        // ✅ ADD FittedBox
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
