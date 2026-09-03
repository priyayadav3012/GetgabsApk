// File: lib/domain/services/notifications_service/notification_service.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:convert';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/data/models/active_chat_model.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:getgabs/domain/services/notifications_service/chat_payload_parser.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:path_provider/path_provider.dart';

import '../../../ui/pages/dashboard/chats/messages_ui/messages_page.dart';

class NotificationService {
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;
  var role = ' '.obs;
  var id = ' '.obs;
  var user_privilage = ' '.obs;

  GetStorageUserData userData = GetStorageUserData();
  RxList<Message> messageChatList = <Message>[].obs;
  final ChatServices chatServices = ChatServices();

  void requestNotificationPermission() async {
    NotificationSettings settings = await firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        carPlay: true,
        criticalAlert: true,
        sound: true,
        provisional: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("User granted permission");
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print("User granted provisional permission");
    } else {
      AppSettings.openAppSettings();
      print("User denied permission");
    }
  }

  // ============================================
  // LOCAL NOTIFICATIONS INIT
  // ✅ Android: flavor-aware notification icon
  // ✅ iOS: DarwinInitializationSettings
  // ============================================
  Future<void> initLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    // ✅ Android: default launcher icon — ic_notification_messagedly was
    // referenced for the messagedly flavor but that mipmap resource was
    // never added, which made initialize() throw and silently blocked
    // chat list loading for that flavor only.
    // ✅ iOS: Android icon relevant nahi — default use hoga
    const String notificationIcon = '@mipmap/ic_launcher';

    const androidInitializationsSettings =
        AndroidInitializationSettings(notificationIcon);
    var iOSInitializationsSettings = const DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
        android: androidInitializationsSettings,
        iOS: iOSInitializationsSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          print("No notification payload received.");
          return;
        }

        try {
          final decodedPayload = jsonDecode(payload);
          final profileData = _extractProfileData(decodedPayload);

          if (profileData != null) {
            final profile = createProfileFromData(profileData);
            handleProfileNavigation(profile);
          } else {
            print("No profile data in notification");
          }
        } catch (e) {
          print("Failed to decode notification payload: $e");
        }
      },
    );

    _localNotificationsInitialized = true;
  }

  // ============================================
  // GET USER TOPIC
  // ============================================
  Future<String?> getUserTopic() async {
    try {
      final value = await userData.getUserDataInOneShot();
      if (value == null) {
        print("No user data found.");
        return null;
      }

      final role = value['role'];
      final id = value['id'];
      final adminId = value['admin_id'];
      final privilege = value['user_privilage'];

      print(value);
      String baseTopicSuffix;
      switch (role) {
        case 'user':
          baseTopicSuffix = "user$id";
          break;
        case 'manager':
          baseTopicSuffix = "user$adminId";
          break;
        case 'sub-user':
          baseTopicSuffix = privilege == 1 ? "user$adminId" : "sub-user$id";
          break;
        default:
          baseTopicSuffix = "app-update";
      }

      print("🎯 [getUserTopic] Computed Topic: $baseTopicSuffix");
      return baseTopicSuffix;
    } catch (e) {
      print("Error determining topic: $e");
      return null;
    }
  }

  // ============================================
  // SUBSCRIBE TO TOPIC
  // ============================================
  void onInitTopic() async {
    try {
      final value = await userData.getUserDataInOneShot();
      if (value == null) return;

      final role = value['role'];
      final id = value['id'];
      final adminId = value['admin_id'];
      final privilege = value['user_privilage'];

      // ✅ Flavor prefix — dono apps ke topics alag
      String baseTopicSuffix;
      switch (role) {
        case 'user':
          baseTopicSuffix = "user$id";
          break;
        case 'manager':
          baseTopicSuffix = "user$adminId";
          break;
        case 'sub-user':
          baseTopicSuffix = privilege == 1 ? "user$adminId" : "sub-user$id";
          break;
        default:
          baseTopicSuffix = "app-update";
      }
      await firebaseMessaging.subscribeToTopic(baseTopicSuffix);
      print("✅ Subscribed to topic: $baseTopicSuffix");
    } catch (e) {
      print("Error initializing topic: $e");
    }
  }

  Future<bool> _isApnsTokenAvailable() async {
    if (!Platform.isIOS) return true;

    try {
      final apnsToken = await firebaseMessaging.getAPNSToken();
      if (apnsToken == null || apnsToken.isEmpty) {
        print("⚠️ APNS token not set yet before unsubscribe.");
        return false;
      }
      print("✅ APNS token available before unsubscribe: $apnsToken");
      return true;
    } catch (e) {
      print("⚠️ APNS token check failed before unsubscribe: $e");
      return false;
    }
  }

  // ============================================
  // UNSUBSCRIBE FROM TOPIC
  // ============================================
  // Returns a Future (rather than fire-and-forget) so callers can await full
  // completion before proceeding — e.g. logout must not call deleteToken()
  // while this is still mid-flight, since both touch the same FCM/APNS
  // instance on iOS and racing them can stall the platform channel.
  // Storage-clearing and login-screen navigation are left to the caller
  // (_handleSignOut) so logout has a single place that does them, instead
  // of this running its own late/duplicate navigation after the caller
  // already has.
  Future<void> onUnsubscribeTopic() async {
    try {
      print("🔄 [onUnsubscribeTopic] Unsubscribe process started...");
      final topic = await getUserTopic();

      if (topic == null) {
        print("⚠️ [onUnsubscribeTopic] Topic NULL — cannot unsubscribe.");
        return;
      }

      if (Platform.isIOS) {
        final apnsReady = await _isApnsTokenAvailable();
        if (!apnsReady) {
          print(
              "⚠️ Skipping unsubscribeFromTopic on iOS because APNS token is not ready.");
          return;
        }
      }

      print("📡 Unsubscribing from: $topic");
      await firebaseMessaging.unsubscribeFromTopic(topic);
      print("✅ UNSUBSCRIBED FROM TOPIC: $topic");
    } catch (e) {
      print("❌ [onUnsubscribeTopic] Error: $e");
    }
  }

  // ============================================
  // CREATE PROFILE FROM MESSAGE
  // ============================================
  Profile createProfileFromData(Map<String, dynamic> data) {
    String? profileWaKey = data['profile_wa_key'];
    String? profileWaId = data["profile_wa_id"];
    String? getPendingMsgCount = data["getpandingmsg_count"];
    String? profileName = data["profile_name"];
    String? updatedTime = data["updatedtime"]?.toString();
    String? voicePermission = data["hasVoiceCallingPermission"]?.toString();

    int? profileWaIdInt = profileWaId != null ? int.tryParse(profileWaId) : 0;
    int? pendingMsgCountInt =
        getPendingMsgCount != null ? int.tryParse(getPendingMsgCount) : 0;

    bool hasVoiceCallingPermissionBool =
        voicePermission?.toLowerCase() == "yes";

    if (profileWaKey == null || profileName == null) {
      throw ArgumentError(
          'Profile data is incomplete. Missing profileWaKey or profileName');
    }

    return Profile(
      profileWaId: profileWaIdInt!,
      profileWaKey: profileWaKey,
      profileName: profileName,
      getPendingMsgCount: pendingMsgCountInt!,
      updatedTime: updatedTime ?? "",
      hasVoiceCallingPermission: hasVoiceCallingPermissionBool,
    );
  }

  Profile createProfileFromMessage(RemoteMessage message) {
    return createProfileFromData(message.data);
  }

  Map<String, dynamic>? _extractProfileData(dynamic payload) {
    if (payload is! Map) {
      return null;
    }

    final payloadMap = Map<String, dynamic>.from(payload);

    if (payloadMap.containsKey('profile_wa_key')) {
      return payloadMap;
    }

    final nestedData = payloadMap['data'];
    if (nestedData is Map<String, dynamic> &&
        nestedData.containsKey('profile_wa_key')) {
      final extracted = Map<String, dynamic>.from(nestedData);

      if (payloadMap['customerprofile_wa_id'] != null &&
          extracted['profile_wa_id'] == null) {
        extracted['profile_wa_id'] =
            payloadMap['customerprofile_wa_id'].toString();
      }

      if (payloadMap['customerprofilename'] != null &&
          extracted['profile_name'] == null) {
        extracted['profile_name'] =
            payloadMap['customerprofilename'].toString();
      }

      return extracted;
    }

    return null;
  }

  // On a cold start, FirebaseMessaging.onMessageOpenedApp and
  // getInitialMessage() can BOTH resolve for the exact same notification
  // tap (a documented Firebase gotcha — see setupInteractMessage() below).
  // Get.to() is an async transition, so if both call handleProfileNavigation
  // back-to-back, Get.currentRoute can still read the OLD route for the
  // second call too, pushing MessagesPage onto the stack twice for one tap.
  // Guards only the "not yet on MessagesPage, navigate there" branch — the
  // in-place update below (already on that chat) is idempotent and safe to
  // run twice regardless.
  static String? _lastNavigatedProfileWaKey;
  static DateTime? _lastNavigatedAt;

  void handleProfileNavigation(Profile profile) {
    if (Get.currentRoute.contains('/MessagesPage')) {
      final MessagesPageController? messagesPageController =
          Get.isRegistered<MessagesPageController>()
              ? Get.find<MessagesPageController>()
              : null;

      if (messagesPageController != null) {
        if (messagesPageController.profileWaKey != profile.profileWaKey) {
          messagesPageController.profileWaId = profile.profileWaId;
          messagesPageController.profileWaKey = profile.profileWaKey;
          messagesPageController.messageChatList.clear();
          messagesPageController.userProfile.value = profile;
          messagesPageController.currentPage.value = 1;
          messagesPageController.loadChatsApi(
              userKey: profile.profileWaKey, from: 'outside');
        }
      } else {
        print(
            "MessagesPageController not found, navigating to new MessagesPage.");
      }
    } else {
      final now = DateTime.now();
      final isDuplicateTap = _lastNavigatedProfileWaKey == profile.profileWaKey &&
          _lastNavigatedAt != null &&
          now.difference(_lastNavigatedAt!) < const Duration(seconds: 3);
      if (isDuplicateTap) {
        print(
            "Skipping duplicate navigation for profile: ${profile.profileWaKey}");
        return;
      }
      _lastNavigatedProfileWaKey = profile.profileWaKey;
      _lastNavigatedAt = now;

      print(
          "Navigating to new MessagesPage for profile: ${profile.profileWaKey}");
      Get.to(() =>
          MessagesPage(profile: profile, profileWaKey: profile.profileWaKey));
    }
  }

  // ============================================
  // FIREBASE INIT — FOREGROUND MESSAGES
  // ============================================
  // FirebaseMessaging.onMessage is a single global stream (tied to
  // FirebaseMessaging.instance, not this NotificationService instance) —
  // NotificationService itself isn't a singleton, so calling firebaseInit()
  // more than once (e.g. DashboardController.onInit() re-running whenever
  // the dashboard route/controller is re-created) added another .listen()
  // subscription each time without ever cancelling the previous one. Every
  // incoming message then fired once per accumulated subscription, causing
  // duplicate chat-list refreshes / mark-as-read calls per message and
  // eventually backend rate-limiting ("Too many requests"). This static
  // flag makes registration a one-time, app-lifetime effect.
  static bool _foregroundListenerRegistered = false;

  void firebaseInit() {
    if (_foregroundListenerRegistered) return;
    _foregroundListenerRegistered = true;
    FirebaseMessaging.onMessage.listen((message) async {
      // 🔎 Full FCM payload as received (foreground) — check this in the
      // console to verify what the backend is actually sending.
      debugPrint('📥 FCM (foreground) message.data: ${message.data}');
      if (message.notification != null) {
        debugPrint('📥 FCM (foreground) notification: '
            'title=${message.notification?.title}, '
            'body=${message.notification?.body}');
      }

      final msgType = message.data['type'] ?? '';
      if (msgType == 'incoming_call' || msgType == 'call_terminated') {
        debugPrint('📞 Call notification — skipping');
        return;
      }

      // Bump the relevant chat to the top / bump its unread badge, and (if
      // that chat is open) deliver the message straight into it. This used
      // to be SocketsController's job (local list manipulation on the
      // 'chatdata' event — no network call), now retired. The very first
      // version of this FCM handling called refreshActiveChatList /
      // refreshRollingOverChatList (a full REST refetch + full list
      // replace) on *every* message instead, which visibly reloaded the
      // entire chat list each time rather than just floating one row to
      // the top — bumpChatOnIncomingMessage() below restores the original,
      // local-only behavior.
      //
      // The backend doesn't currently send `type: 'new_message'` on chat
      // payloads (only `subuser`/`data2`), so detection falls back to
      // isChatMessagePayload() — without it none of this ever ran.
      final isChatMessage = isChatMessagePayload(message.data);
      var isCurrentlyOpenChat = false;
      if (isChatMessage) {
        final chatData = decodeChatPayload(message.data);
        final incomingWaKey = chatData?['profile_wa_key']?.toString();

        isCurrentlyOpenChat = incomingWaKey != null &&
            Get.isRegistered<MessagesPageController>() &&
            Get.find<MessagesPageController>().profileWaKey == incomingWaKey;

        if (incomingWaKey != null && Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().bumpChatOnIncomingMessage(
            profileWaKey: incomingWaKey,
            customerName: chatData?['profile_name']?.toString() ?? 'Unknown',
            customerWaId:
                int.tryParse(chatData?['profile_wa_id']?.toString() ?? '') ?? 0,
            isCurrentlyOpen: isCurrentlyOpenChat,
          );
        }

        if (isCurrentlyOpenChat) {
          Get.find<MessagesPageController>()
              .handleIncomingMessage({'data': chatData});
        }
      }

      if (Platform.isIOS) {
        iosForegroundMessage();
        return;
      }

      if (Platform.isAndroid) {
        // ✅ KEY FIX — notification block present hai
        // toh Android OS already show kar dega
        // hum dobara show nahi karenge = double band
        if (message.notification != null) {
          debugPrint('⏭️ Skipping — Android OS will show automatically');
          return;
        }

        // Socket used to own foreground chat notifications
        // (SocketsController.handleNotification()) — now retired, so this
        // is the only thing left that can show one. Only suppress it for
        // the chat currently open on screen (already visible there); any
        // other incoming chat message should still alert, same as it would
        // in background.
        if (isChatMessage && isCurrentlyOpenChat) {
          debugPrint('⏭️ Skipping — this chat is already open on screen');
          return;
        }

        // Sirf data-only messages pe manually show karo
        if (message.data.isNotEmpty) {
          showNotification(message);
        }
      }
    });
  } // ============================================

  // BACKGROUND / TERMINATED MESSAGE HANDLER
  // ============================================
  // Same accumulation issue as firebaseInit() above: DashboardController.
  // onInit() calls this unconditionally every time it re-runs, and
  // FirebaseMessaging.onMessageOpenedApp is a single global stream — without
  // this guard, each accumulated listener re-fired handleProfileNavigation()
  // for the same notification tap, which (when switching chats) calls
  // loadChatsApi(from: 'outside') → messageChatList.assignAll(...). Multiple
  // concurrent/racing calls to that meant a slower, staler REST response
  // could land after a live FCM-inserted message and wipe it from the list
  // — looking exactly like the message had been deleted.
  static bool _interactMessageListenerRegistered = false;

  Future<void> setupInteractMessage() async {
    if (_interactMessageListenerRegistered) return;
    _interactMessageListenerRegistered = true;
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('📥 FCM (opened from tray) message.data: ${message.data}');
      final profileData = _extractProfileData(message.data);

      if (profileData != null) {
        print('fire notifcationssssssssssss');
        var profile = createProfileFromData(profileData);
        handleProfileNavigation(profile);
      } else {
        print("Topic Notification received without profile data");
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📥 FCM (initial/terminated) message.data: ${message.data}');
      }
      if (message != null && message.data.isNotEmpty) {
        // ✅ Call notifications skip karo
        final msgType = message.data['type'] ?? '';
        if (msgType == 'incoming_call' || msgType == 'call_terminated') {
          debugPrint('📞 Call notification in getInitialMessage — skipping');
          return;
        }
        final profileData = _extractProfileData(message.data);

        if (profileData != null) {
          var profile = createProfileFromData(profileData);
          handleProfileNavigation(profile);
        } else {
          print("Topic Notification received without profile data");
        }
      }
    });
  }

  void navigateToMessagesPage(Profile profile) {
    Get.to(
        () =>
            MessagesPage(profile: profile, profileWaKey: profile.profileWaKey),
        arguments: {
          'profileId': profile.profileWaId,
          'profileName': profile.profileName,
        });
  }

  Future<void> showChatNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
        'message', 'text',
        importance: Importance.max,
        playSound: true,
        showBadge: true,
        enableVibration: true);

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(channel.id, channel.name,
            channelDescription: 'used for showing chat messages.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            ticker: 'ticker',
            enableVibration: true);
    DarwinNotificationDetails darwinNotificationDetails =
        const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true);
    NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: darwinNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  // ============================================
  // SHOW SIMPLE NOTIFICATION
  // ============================================
  void showSimpleNotification(RemoteMessage message) {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
        'id', 'notification simple',
        importance: Importance.high,
        playSound: true,
        showBadge: true,
        enableVibration: true);

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(channel.id, channel.name,
            channelDescription: 'used for showing chat messages.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            ticker: 'ticker',
            enableVibration: true);
    DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true);
    NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: darwinNotificationDetails);
    _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: message.notification!.title,
      body: message.notification!.body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // ============================================
  // SHOW RICH NOTIFICATION (with image)
  // ============================================
  Future<void> showNotification(RemoteMessage message) async {
    if (message.data.isEmpty) {
      print("Notification data is empty.");
      return;
    }
    final data = message.data;
    final type = data['type'];
    final imageUrl = data['image'];

    AndroidNotificationChannel channel = AndroidNotificationChannel(
        message.notification?.android?.channelId ?? 'message',
        message.notification?.android?.channelId ?? 'message',
        importance: Importance.max,
        playSound: true,
        showBadge: true,
        enableVibration: true);

    BigPictureStyleInformation? styleInformation;
    if (type == 'image' && imageUrl != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/notification_image.jpg';
        await Dio().download(imageUrl, filePath);
        styleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(filePath),
          contentTitle: message.notification?.title,
          summaryText: message.notification?.body,
        );
      } catch (e) {
        print("Image download failed: $e");
      }
    }

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: "YOUR CHANNEL DESCRIPTION",
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      ticker: 'ticker',
      enableVibration: true,
      styleInformation: styleInformation,
    );

    DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    // message.notification is null for data-only chat payloads (the normal
    // case here) — force-unwrapping it used to throw a null-check error on
    // every one of these, silently swallowed as an "Unhandled Exception"
    // with no notification ever actually shown.
    final chatData = decodeChatPayload(data);

    _flutterLocalNotificationsPlugin.show(
      id: chatNotificationId(chatData),
      title: message.notification?.title ?? chatSenderName(chatData),
      body: message.notification?.body ?? chatPreviewText(chatData),
      notificationDetails: notificationDetails,
      payload: "data",
    );
  }

  // ============================================
  // GET DEVICE TOKEN
  // ============================================
  Future<String> getDeviceToken() async {
    String? token = await firebaseMessaging.getToken();
    print("device token: $token");
    return token ?? 'no_token_available';
  }

  // ============================================
  // iOS FOREGROUND MESSAGE SETTINGS
  // ============================================
  void iosForegroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true);
  }
}
