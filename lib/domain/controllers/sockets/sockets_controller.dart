import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client_new/socket_io_client_new.dart' as IO;
import '../../../data/get_storage/get_storage.dart';

import '../../services/notifications_service/notification_service.dart';

class SocketsController extends GetxController with WidgetsBindingObserver {
  static SocketsController instance = Get.find();
  GetStorageUserData userData = GetStorageUserData();
  final NotificationService notificationService = NotificationService();

  late IO.Socket _socket;
  // _socket is `late` and only assigned once _initializeSocket() confirms an
  // API key is available (it aborts early otherwise) — this guards every
  // other access against a LateInitializationError if a lifecycle callback
  // fires before that.
  bool _socketReady = false;
  var isAppInForeground = true.obs;

  /// The currently-open chat, if any. Set by [MessagesPageController.onInit]
  /// and cleared on its close. Incoming socket events are delivered straight
  /// to this controller instead of each page registering its own raw
  /// `socket.on(...)` listener — the old approach never called `off()`, so
  /// listeners accumulated across chat opens/rebuilds and a throw in any one
  /// stale listener aborted the emitter's dispatch loop before the live chat's
  /// handler ran, which is why new messages only appeared after a reopen.
  MessagesPageController? _openChat;

  void registerOpenChat(MessagesPageController controller) {
    _openChat = controller;
    _joinChatRoom(controller.profileWaKey);
  }

  void unregisterOpenChat(MessagesPageController controller) {
    if (identical(_openChat, controller)) {
      _leaveChatRoom(controller.profileWaKey);
      _openChat = null;
    }
  }

  // Tells the backend which chat this socket connection is currently
  // viewing. Needed so it knows which OTHER connected agent sessions to
  // relay this chat's 'typing' events to (a plain per-connection role/id at
  // 'connectchannel' time isn't enough — that never carries a chat, only
  // who the logged-in user is) — without this, there's no way for the
  // server to route a "typing" emit to the right teammates at all. Harmless
  // no-op if the backend doesn't implement 'join_chat'/'leave_chat' yet.
  void _joinChatRoom(String profileWaKey) {
    if (!_socketReady || profileWaKey.isEmpty) return;
    try {
      _socket.emit('join_chat', {'profile_wa_key': profileWaKey});
      debugPrint('📡 emit join_chat: $profileWaKey');
    } catch (e) {
      debugPrint('❌ Error emitting join_chat: $e');
    }
  }

  void _leaveChatRoom(String profileWaKey) {
    if (!_socketReady || profileWaKey.isEmpty) return;
    try {
      _socket.emit('leave_chat', {'profile_wa_key': profileWaKey});
    } catch (e) {
      debugPrint('❌ Error emitting leave_chat: $e');
    }
  }

  @override
  void onInit() async {
    super.onInit();
    await _initializeSocket();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initializeSocket() async {
    String platform = Platform.isIOS ? "ios" : "android";
    var role = await userData.getUserRole();
    var userId = await userData.getLoggedInUserId();
    var userPrivilage = await userData.getUserPrivilage();
    var adminId =
        role == "user" ? await userData.getParentUserId() : userId.toString();

    // The socket server authenticates against the top-level auth token, NOT
    // the WhatsApp/facebook_details key that getApiKey() returns (which the
    // server rejects with "Invalid API key"). Fall back to the REST key only
    // if no auth token is stored, so we never regress below prior behavior.
    var apiKey = await userData.getSocketAuthKey();
    if (apiKey.isEmpty) {
      apiKey = await userData.getApiKey();
    }

    if (apiKey.isEmpty) {
      debugPrint('❌ Socket initialization aborted: API key is undefined or empty');
      return;
    }

    initializeSocket(platform, role, userId.toString(), userPrivilage, adminId, apiKey);
  }

  bool isOnMessagesPage(String incomingWaKey) {
    if (Get.currentRoute.contains('/MessagesPage')) {
      final MessagesPageController? messagesPageController =
          Get.isRegistered<MessagesPageController>()
              ? Get.find<MessagesPageController>()
              : null;

      if (messagesPageController != null) {
        return incomingWaKey == messagesPageController.profileWaKey;
      }
    }
    return false;
  }

  void initializeSocket(String Platform,
      String userRole, String userId, int userPrivilage, var adminId, String apiKey) {
    _socket = IO.io(
        'https://app.getgabs.com:56000',
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({
            'api_key': apiKey
      })
            .enableForceNew()
            .build());
    _socketReady = true;

    // Error-only listeners: silent during normal operation, but surface the
    // reason (e.g. "Invalid API key", disconnects) if the socket ever fails to
    // connect or drops — useful for diagnosing live-chat outages.
    _socket.on('connect_error', (err) => debugPrint('socket connect_error: $err'));
    _socket.on('error', (err) => debugPrint('socket error: $err'));
    _socket.on('disconnect', (reason) => debugPrint('socket disconnected: $reason'));

    _socket.on('connect', (data) {
      var userinfo = {
        'platform': Platform, // new parameter
        'role': userRole,
        'id': userId,
        'user_privilage': userPrivilage,
        'admin_id': adminId
      };
      _socket.emit('connectchannel', userinfo);

      // A reconnect (network blip, app backgrounded then resumed, server
      // restart) means we may have missed 'chatdata'/'messagestatus' events
      // while disconnected — sockets don't queue undelivered events the way
      // FCM does. Re-fetch the currently-open chat from REST so nothing is
      // silently missing; skipped on the very first connect since that chat
      // was already loaded via the normal REST call when it was opened.
      if (_hasConnectedBefore) {
        final openChat = _openChat;
        if (openChat != null) {
          // A fresh connection means a fresh server-side session — any
          // chat-room membership from before the drop is gone, so re-join.
          _joinChatRoom(openChat.profileWaKey);
          openChat.loadChatsApi(userKey: openChat.profileWaKey, from: 'outside');
        }
      } else {
        // First-ever connect: registerOpenChat() may have already run and
        // tried to join before the socket was ready (e.g. cold start racing
        // MessagesPageController.onInit against this async _initializeSocket),
        // in which case that join was silently skipped — join now instead.
        final openChat = _openChat;
        if (openChat != null) {
          _joinChatRoom(openChat.profileWaKey);
        }
      }
      _hasConnectedBefore = true;
    });

    // Scoped ONLY to the currently-open chat (see registerOpenChat) — this is
    // an ADDITIVE fast-path for near-instant delivery while that chat is on
    // screen and the app is foreground. Any message for a different/closed
    // chat is left entirely to FCM (NotificationService.firebaseInit() /
    // the background handler in main.dart), which already handles the
    // dashboard-list bump and notification for that case unchanged. This
    // split matters: bumpChatOnIncomingMessage() increments the unread badge
    // by 1 per call with no de-dupe, so letting BOTH FCM and this socket
    // bump a NOT-open chat would double-count it. handleIncomingMessage()
    // (the open-chat path) IS safe to call from both — it de-dupes by
    // messageId — so no special guarding is needed there.
    _socket.on('chatdata', (data) {
      try {
        final messageData = data['data'];
        if (messageData == null) return;
        final incomingWaKey = messageData['profile_wa_key']?.toString();
        if (incomingWaKey == null || incomingWaKey.isEmpty) return;

        final openChat = _openChat;
        if (openChat == null || openChat.profileWaKey != incomingWaKey) {
          return; // Not the open chat — FCM already covers this.
        }

        openChat.handleIncomingMessage(data);

        if (Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().bumpChatOnIncomingMessage(
            profileWaKey: incomingWaKey,
            customerName: data['customerprofilename']?.toString() ?? 'Unknown',
            customerWaId: int.tryParse(
                    data['customerprofile_wa_id']?.toString() ?? '') ??
                0,
            isCurrentlyOpen: true, // always 0-badge/reorder-only — safe to repeat
          );
        }
      } catch (e) {
        debugPrint('❌ Error handling chatdata: $e');
      }
    });

    // Typing indicator — client is ready to emit/receive this the moment the
    // backend relays it; until then this is a harmless no-op (emitting an
    // event the server doesn't act on yet, listening for one it never
    // sends). See emitTyping()/emitStopTyping() below for the emit side.
    _socket.on('typing', (data) {
      debugPrint('📥 received typing event: $data');
      try {
        final incomingWaKey = data['profile_wa_key']?.toString();
        final openChat = _openChat;
        if (openChat == null || openChat.profileWaKey != incomingWaKey) return;
        openChat.receiveTypingEvent(data['is_typing'] == true);
      } catch (e) {
        debugPrint('❌ Error handling typing event: $e');
      }
    });

    // Single app-lifetime listener for delivery-status updates, routed to the
    // open chat. Previously each MessagesPageController registered its own
    // 'messagestatus' listener and never removed it, so these accumulated the
    // same way 'chatdata' did.
    _socket.on('messagestatus', (data) {
      try {
        _openChat?.handelIcomingMessageStatus(data);
      } catch (e) {
        print('❌ Error handling message status: $e');
      }
    });
  }

  bool _hasConnectedBefore = false;

  // Lets the currently-open chat tell the other side it's typing. Silently
  // a no-op if the socket isn't connected — never worth surfacing an error
  // for what's purely a nice-to-have indicator.
  void emitTyping(String profileWaKey) => _emitTypingState(profileWaKey, true);
  void emitStopTyping(String profileWaKey) =>
      _emitTypingState(profileWaKey, false);

  void _emitTypingState(String profileWaKey, bool isTyping) {
    if (!_socketReady) {
      debugPrint('⚠️ emitTyping skipped — socket not ready yet');
      return;
    }
    try {
      _socket.emit('typing', {
        'profile_wa_key': profileWaKey,
        'is_typing': isTyping,
      });
      debugPrint('📡 emit typing: $profileWaKey is_typing=$isTyping '
          '(socket connected=${_socket.connected})');
    } catch (e) {
      debugPrint('❌ Error emitting typing state: $e');
    }
  }

  void handleNotification(dynamic data) {
    String messageType = data['data']['message_type'];
    String title = data['customerprofilename'];
    String payLoad = jsonEncode(data);

    String body;
    switch (messageType) {
      case 'text':
        body = data['data']['message_text'];
        break;
      case 'image':
        body = 'Image';
        break;
      case 'video':
        body = 'Video';
        break;
      case 'document':
        body = 'Document';
        break;
      case 'reply_msg':
        body = 'Reply Message';
        break;
      default:
        body = 'Message';
        break;
    }
    if (isAppInForeground.value) {
      notificationService.showChatNotification(
        title: title,
        body: body,
        payload: payLoad,
      );
    }
  }

  void handleIncomingMessage(dynamic data) {
    // Process the incoming message data
    print('Received message: $data');
  }

  void disconnectSocket() {
    _socket.disconnect();
    _socket.close();
    print('Socket disconnected');
  }

  void reconnectSocket() {
    _initializeSocket();
    print('Socket reconnected');
  }

  void updateChatToRead(
      {required String role,
      required int userId,
      required String adminId,
      required String messageId,
      required String profileWaKey}) {
    var data = {
      'role': role,
      'id': userId
          .toString(), // ensure id is sent as string to match connect payload
      'admin_id': adminId,
      'message_id': messageId,
      'profile_wa_key': profileWaKey
    };
    _socket.emit('updatechattoread', data);
    print('updatechattoread event emitted with data: $data');
  }

  IO.Socket get socket => _socket;

  @override
  void onClose() {
    disconnectSocket();
    WidgetsBinding.instance.removeObserver(this);

    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      isAppInForeground.value = true; // App is in the foreground
      // Socket is a foreground-only fast path (see the 'chatdata' listener's
      // doc comment) — reconnect here since it was dropped on pause below.
      // The 'connect' handler's resync (loadChatsApi) covers anything
      // missed while disconnected.
      try {
        if (_socketReady && !_socket.connected) {
          _socket.connect();
        }
      } catch (e) {
        debugPrint('❌ Error reconnecting socket on resume: $e');
      }
    } else if (state == AppLifecycleState.paused) {
      isAppInForeground.value = false; // App is in the background
      // Drop the connection while backgrounded: nothing reads it there
      // (FCM/APNs — not this socket — is what delivers background
      // notifications), so holding it open would just burn battery/radio
      // for no benefit, and iOS is stricter than Android about background
      // network execution.
      try {
        if (_socketReady && _socket.connected) {
          _socket.disconnect();
        }
      } catch (e) {
        debugPrint('❌ Error disconnecting socket on pause: $e');
      }
    }
  }
}

/// Function to check and request microphone permission for voice calls
Future<bool> hasVoiceCallPermission() async {
  var status = await Permission.microphone.status;

  if (status.isGranted) {
    return true;
  }

  if (status.isDenied) {
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  }

  return false;
}

  /*
//-----####----------------------uncomment-later-------------####-------------------------


  //-----####----------------------uncomment-later-------------####-------------------------
  */















// import 'package:get/get.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;

// import '../../../data/get_storage/get_storage.dart';

// class SocketsController extends GetxController {
//   static SocketsController instance = Get.find();
//   GetStorageUserData userData = GetStorageUserData();

//   late IO.Socket _socket;
//   @override
//   void onInit() async {
//     super.onInit();
//     var role = await userData.getUserRole();
//     var userId = await userData.getLoggedInUserId();
//     print(role);
//     print(userId.toString());
//     initializeSocket(role, userId.toString());
//   }

//   void initializeSocket(String userRole, String userId) {
//     _socket = IO.io(
//       'https://app.getgabs.com:56000',
//       IO.OptionBuilder().setTransports(['websocket', 'polling']).build(),
//     );

//     _socket.on('connect', (_) {
//       print('Connected to socket');
//       var userinfo = {
//         'role': userRole,
//         'id': userId,
//       };
//       _socket.emit('connectchannel', userinfo);
//     });

//     _socket.on('chatdata', (data) {
//       print('Chat data: $data');
//       handleIncomingMessage(data);
//     });

//     // _socket.on('disconnect', (_) {
//     //   print('Disconnected from socket');
//     // });
//   }

//   void handleIncomingMessage(dynamic data) {
//     // Process the incoming message data
//     print('Received message: $data');
//   }

//   IO.Socket get socket => _socket;

//   @override
//   void onClose() {
//     socket.dispose();
//     super.onClose();
//   }
// }
