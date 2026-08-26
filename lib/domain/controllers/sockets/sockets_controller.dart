import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client_new/socket_io_client_new.dart' as IO;
import '../../../data/get_storage/get_storage.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../data/models/active_chat_model.dart'; // Import notification package
import '../../services/notifications_service/notification_service.dart';

class SocketsController extends GetxController with WidgetsBindingObserver {
  static SocketsController instance = Get.find();
  GetStorageUserData userData = GetStorageUserData();
  final NotificationService notificationService = NotificationService();

  late IO.Socket _socket;
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
  }

  void unregisterOpenChat(MessagesPageController controller) {
    if (identical(_openChat, controller)) {
      _openChat = null;
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
    });
/*
    _socket.on('chatdata', (data) {
      print('Chat data socket: $data');
      var messageData = data['data'];

      try {
        var dc = Get.find<DashboardController>();

        if (Get.currentRoute.contains('/MessagesPage')) {
          print('shocket notifcationssssssssssss');
          final MessagesPageController? messagesPageController =
              Get.isRegistered<MessagesPageController>()
                  ? Get.find<MessagesPageController>()
                  : null;
          // var profile = createProfileFromMessage(message);
          if (messagesPageController != null) {
            if (messageData['profile_wa_key'] !=
                messagesPageController.profileWaKey) {
              dc.refreshActiveChatList();
              handleNotification(data);
            } else {
              if (!isAppInForeground.value) {
                dc.refreshActiveChatList();
                handleNotification(data);
              }
            }
          }
        } else {
          dc.refreshActiveChatList();
          handleNotification(data);
        }
      } catch (e) {
        print(e);
      }
      //  handleIncomingMessage(data);
    });
 */

// _socket.on('chatdata', (data) async {

//   print('Chat data socket88: $data');

//   var messageData = data['data'];

//   String name = data['customerprofilename'] ?? "";
//   String mobNumber = data['customerprofile_wa_id']?.toString() ?? "";

//   // ✅ correct path
//   // String callStatus = messageData['callHistory']?['call_status'] ?? "";
//   final data1 = jsonDecode(data);

// final callStatus = data1['data']['callHistory']['call_status'];
// print(callStatus);

//   print("📞 Call Status: $callStatus");

//   if (callStatus == "call_terminated") {
//     print('📴 Call terminated');

//     if (Get.isDialogOpen ?? false) {
//       Get.back();
//     }
//   }

//   try {

//     var dc = Get.find<DashboardController>();

//     String incomingWaKey = messageData['profile_wa_key'];

//     int existingIndex = dc.activeProfileDetailsList
//         .indexWhere((profile) => profile.profileWaKey == incomingWaKey);

//     if (existingIndex != -1) {

//       var existingProfile = dc.activeProfileDetailsList.removeAt(existingIndex);

//       dc.activeProfileDetailsList.insert(
//         0,
//         existingProfile.copyWith(
//           getPendingMsgCount:
//               isOnMessagesPage(incomingWaKey)
//                   ? 0
//                   : existingProfile.getPendingMsgCount + 1,
//         ),
//       );

//     } else {

//       int count = isOnMessagesPage(incomingWaKey) ? 0 : 1;

//       dc.activeProfileDetailsList.insert(
//         0,
//         Profile(
//           profileWaId: int.tryParse(mobNumber) ?? 0,
//           profileWaKey: incomingWaKey,
//           profileName: name,
//           getPendingMsgCount: count,
//           updatedTime:
//               DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
//           hasVoiceCallingPermission: false,
//         ),
//       );
//     }

//     if (Get.currentRoute.contains('/MessagesPage')) {
//       print('Socket notifications');
//       final MessagesPageController? messagesPageController =
//           Get.isRegistered<MessagesPageController>()
//               ? Get.find<MessagesPageController>()
//               : null;

//       if (messagesPageController != null) {
//         if (incomingWaKey != messagesPageController.profileWaKey) {
//        //   dc.refreshActiveChatList();
//           handleNotification(data);
//         } else {
//           if (!isAppInForeground.value) {
//           //  dc.refreshActiveChatList();
//             handleNotification(data);
//           }
//         }
//       }
//     } else {
//     //  dc.refreshActiveChatList();
//       handleNotification(data);
//     }

//   } catch (e) {
//     print("❌ Socket Error: $e");
//   }
// });
    // _socket.on('chatdata', (data) async {
    //   print('Chat data socket33: $data');
    //   var messageData = data['data'];
    //   String name = data['customerprofilename'];
    //   String mobNumber = data['customerprofile_wa_id'];

    //   if (Get.isDialogOpen ?? false) {
    //     Get.back();
    //   }

    //   try {
    //     var dc = Get.find<DashboardController>();
    //     // Extract profileWaKey from incoming data
    //     String incomingWaKey = messageData['profile_wa_key'];
    //     //int pendingMsgCount = messageData['getpendingmsg_count'];

    //     // Find the existing profile if it exists
    //     int existingIndex = dc.activeProfileDetailsList
    //         .indexWhere((profile) => profile.profileWaKey == incomingWaKey);

    //     final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    //     // Also check the rolling-over (closed) tab — previously only the
    //     // active tab ever reordered/refreshed on a live incoming message.
    //     int existingRollingIndex = dc.rollingOverProfileDetailsList
    //         .indexWhere((profile) => profile.profileWaKey == incomingWaKey);

    //     if (existingIndex != -1) {
    //       print('exists---------------------');
    //       // Profile exists, bring it to the top
    //       var existingProfile =
    //           dc.activeProfileDetailsList.removeAt(existingIndex);
    //       dc.activeProfileDetailsList.insert(
    //         0,
    //         existingProfile.copyWith(
    //           getPendingMsgCount: isOnMessagesPage(incomingWaKey)
    //               ? 0
    //               : existingProfile.getPendingMsgCount +
    //                   1, // Update pending message count
    //           updatedTime: nowStr,
    //         ),
    //       );
    //     } else if (existingRollingIndex != -1) {
    //       print('exists in rolling-over---------------------');
    //       var existingRollingProfile =
    //           dc.rollingOverProfileDetailsList.removeAt(existingRollingIndex);
    //       dc.rollingOverProfileDetailsList.insert(
    //         0,
    //         existingRollingProfile.copyWith(
    //           getPendingMsgCount: isOnMessagesPage(incomingWaKey)
    //               ? 0
    //               : existingRollingProfile.getPendingMsgCount + 1,
    //           updatedTime: nowStr,
    //         ),
    //       );
    //     } else {
    //       print('new---------------------');

    //       // Profile does not exist, create a new one and add it to the top
    //       int count = 1;
    //       if (isOnMessagesPage(incomingWaKey)) {
    //         count = 0;
    //       }

    //       dc.activeProfileDetailsList.insert(
    //         0,
    //         Profile(
    //           profileWaId: int.parse(mobNumber),
    //           profileWaKey: incomingWaKey,
    //           profileName: name,
    //           getPendingMsgCount: count,
    //           updatedTime: nowStr,
    //           hasVoiceCallingPermission: false,
    //         ),
    //       );
    //       // dc.activeProfileDetailsList.insert(
    //       //   0,
    //       //   Profile(
    //       //     profileWaId:int.parse(mobNumber) ,
    //       //     profileWaKey: incomingWaKey,
    //       //     profileName: name,
    //       //     getPendingMsgCount: count,
    //       //   ),
    //       // );
    //     }

    //     // Deliver the message into the open chat live (WhatsApp-style) so it
    //     // renders instantly without needing a reopen. Guarded by the wa-key so
    //     // a message for a different chat never lands in the wrong conversation.
    //     final openChat = _openChat;
    //     final bool isForOpenChat =
    //         openChat != null && openChat.profileWaKey == incomingWaKey;
    //     if (isForOpenChat) {
    //       try {
    //         openChat.handleIncomingMessage(data);
    //       } catch (e) {
    //         debugPrint('Error delivering live message to open chat: $e');
    //       }
    //     }

    //     if (Get.currentRoute.contains('/MessagesPage')) {
    //       print('Socket notifications');
    //       if (isForOpenChat) {
    //         // Same chat is open and in the foreground: no notification needed.
    //         if (!isAppInForeground.value) {
    //           handleNotification(data);
    //         }
    //       } else {
    //         // A chat is open but the message is for a different conversation.
    //         handleNotification(data);
    //       }
    //     } else {
    //       //  dc.refreshActiveChatList();
    //       handleNotification(data);
    //     }
    //   } catch (e) {
    //     print(e);
    //   }
    // });

    
    
    
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
    } else if (state == AppLifecycleState.paused) {
      isAppInForeground.value = false; // App is in the background
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
