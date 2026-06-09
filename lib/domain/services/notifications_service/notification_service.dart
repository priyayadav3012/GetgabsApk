// File: lib/domain/services/notifications_service/notification_service.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/data/models/active_chat_model.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:getgabs/domain/services/notifications_service/get_server_key.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:getgabs/ui/pages/dashboard/dashboard.dart';
import 'package:path_provider/path_provider.dart';

import '../../../routes/app_route.dart';
import '../../../ui/pages/dashboard/chats/messages_ui/messages_page.dart';

class NotificationService {
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
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
  void initLocalNotifications(RemoteMessage message) async {
    // ✅ Android: Messagedly flavor ke liye alag icon
    // ✅ iOS: Android icon relevant nahi — default use hoga
    final String notificationIcon =
        LoginWithEmailController.currentFlavor == 'messagedly'
            ? '@mipmap/ic_notification_messagedly'
            : '@mipmap/ic_launcher';

    var androidInitializationsSettings =
        AndroidInitializationSettings(notificationIcon);
    var iOSInitializationsSettings = const DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
        android: androidInitializationsSettings,
        iOS: iOSInitializationsSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (payload) {
        print('hi this is it');
        if (message.data.containsKey('profile_wa_key')) {
          var profile = createProfileFromMessage(message);
          handleMessage(message, profile: profile);
        } else {
          print("No profile data in notification");
        }
      },
    );
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
  void onUnsubscribeTopic() async {
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
          userData.clearAllData();
          Get.offAllNamed(AppRoute.loginWithEmail);
          return;
        }
      }

      print("📡 Unsubscribing from: $topic");
      await firebaseMessaging.unsubscribeFromTopic(topic);
      print("✅ UNSUBSCRIBED FROM TOPIC: $topic");

      userData.clearAllData();
      Get.offAllNamed(AppRoute.loginWithEmail);
    } catch (e) {
      print("❌ [onUnsubscribeTopic] Error: $e");
      userData.clearAllData();
      Get.offAllNamed(AppRoute.loginWithEmail);
    }
  }

  // ============================================
  // CREATE PROFILE FROM MESSAGE
  // ============================================
  Profile createProfileFromMessage(RemoteMessage message) {
    Map<String, dynamic> data = message.data;

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

  // ============================================
  // FIREBASE INIT — FOREGROUND MESSAGES
  // ============================================
  void firebaseInit() {
    FirebaseMessaging.onMessage.listen((message) async {
      final msgType = message.data['type'] ?? '';
      if (msgType == 'incoming_call' || msgType == 'call_terminated') {
        debugPrint('📞 Call notification — skipping');
        return;
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

        // Sirf data-only messages pe manually show karo
        if (message.data.isNotEmpty) {
          showNotification(message);
        }
      }
    });
  } // ============================================

  // BACKGROUND / TERMINATED MESSAGE HANDLER
  // ============================================
  Future<void> setupInteractMessage() async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('background=============++++++++++++++');
      if (message.data.containsKey('profile_wa_key')) {
        print('fire notifcationssssssssssss');
        var profile = createProfileFromMessage(message);
        handleMessage(message, profile: profile);
      } else {
        print("Topic Notification received without profile data");
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      print('now message has arrived.');
      if (message != null && message.data.isNotEmpty) {
        // ✅ Call notifications skip karo
        final msgType = message.data['type'] ?? '';
        if (msgType == 'incoming_call' || msgType == 'call_terminated') {
          debugPrint('📞 Call notification in getInitialMessage — skipping');
          return;
        }
        if (message.data.containsKey('profile_wa_key')) {
          var profile = createProfileFromMessage(message);
          Get.to(() => MessagesPage(
              profile: profile, profileWaKey: profile.profileWaKey));
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification!.title,
        message.notification!.body,
        notificationDetails);
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

    _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No Body',
      notificationDetails,
      payload: "data",
    );
  }

  // ============================================
  // GET DEVICE TOKEN
  // ============================================
  Future<String> getDeviceToken() async {
    String? token = await firebaseMessaging.getToken();
    GetServerKey getServerKey = GetServerKey();
    String accessToken = await getServerKey.getServerToken();
    print(accessToken);
    print("device token: $token");
    return token ?? 'no_token_available';
  }

  // ============================================
  // HANDLE MESSAGE NAVIGATION
  // ============================================
  void handleMessage(RemoteMessage message, {required Profile profile}) async {
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
      print(
          "Navigating to new MessagesPage for profile: ${profile.profileWaKey}");
      Get.to(() =>
          MessagesPage(profile: profile, profileWaKey: profile.profileWaKey));
    }
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
