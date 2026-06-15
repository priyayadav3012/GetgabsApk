// File: lib/main.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/firebase_options.dart';
import 'package:getgabs/routes/app_page.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/services/whtasapp_calling_service.dart';


final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ✅ Dono platforms ke liye global flags
bool isAppInForeground = true;
bool _isCallScreenOpen = false;

// ============================================
// LIFECYCLE OBSERVER
// ✅ iOS: foreground aane pe pending navigation check
// ✅ Android: bhi same kaam karega — no harm
// ============================================
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isAppInForeground = state == AppLifecycleState.resumed;
    debugPrint(isAppInForeground ? '🟢 FOREGROUND' : '🔴 BACKGROUND');

    if (state == AppLifecycleState.resumed) {
      // #changedWithJClaude — Bug 6: reduced from 800 ms to 100 ms so answerCall()
      // reaches the server before the call times out on foreground resume.
      Future.delayed(const Duration(milliseconds: 100), () {
        WhatsAppCallingConfig.handlePendingCallNavigation();
      });
    }
  }
}

// ============================================
// BACKGROUND FCM HANDLER
// ✅ iOS: UUID generate karta hai + 'default' audioSessionMode
// ✅ Android: original callId use karta hai + AndroidParams styling
// ============================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['type'];
  final prefs = await SharedPreferences.getInstance();

  if (type == 'incoming_call') {
    final callId = message.data['call_id'] ?? '';
    final callerName = message.data['caller_name'] ?? 'Unknown';
    final callerNumber = message.data['caller_number'] ?? '';
    final sessionRaw = message.data['session'] ?? '';

    // Always store call metadata — SDP source for both platforms
    await prefs.setString('pending_call_id', callId);
    await prefs.setString('pending_call_session', sessionRaw);
    await prefs.setString('pending_caller_name', callerName);
    await prefs.setString('pending_caller_number', callerNumber);
    await prefs.setString(
        'pending_from_user_id', message.data['from_user_id'] ?? '');

    // #changedWithJClaude — Bug 3 fix REVERTED: restore flutter_callkit_incoming on iOS.
    // The original removal assumed VoIP push would reliably show native CallKit on its own,
    // but VoIP push delivery is not guaranteed. FCM-triggered CallKit is the safety net.
    // UUID alignment: AppDelegate writes pending_callkit_id = VoIP UUID when VoIP push
    // fires (which arrives before FCM on iOS). We reuse that UUID here so both CXProviders
    // refer to the same call. If native CallKit already showed, iOS rejects the duplicate
    // silently and the native UI stays. If VoIP push hasn't fired yet, we generate a new
    // UUID and the plugin CallKit shows — answer path via CallEventActionCallAccept works
    // correctly with Bugs 1/2/4/5/6 fixes in place.
    final String safeId;
    if (Platform.isIOS) {
      final voipUuid = prefs.getString('pending_callkit_id') ?? '';
      safeId = voipUuid.isNotEmpty ? voipUuid : const Uuid().v4();
    } else {
      safeId = callId;
    }
    await prefs.setString('pending_callkit_id', safeId);

    final displayForAvatar = callerName.isNotEmpty
        ? callerName
        : callerNumber.replaceAll('+', '').replaceAll(' ', '');
    final avatarUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayForAvatar)}&background=075E54&color=ffffff&size=200&rounded=true&bold=true';

    String displayName = callerName.isNotEmpty ? callerName : callerNumber;
    String displayNameShort = displayName.length > 25
        ? '${displayName.substring(0, 25)}...'
        : displayName;

    final params = CallKitParams(
      id: safeId,
      nameCaller: displayNameShort,
      handle: callerNumber,
      appName: 'GetGabs',
      avatar: avatarUrl,
      type: 0,
      duration: 60000,
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#034737',
        actionColor: '#034737',
        textColor: '#ffffff',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'number',
        supportsVideo: false,
        supportsGrouping: false,
        supportsHolding: false,
        supportsUngrouping: false,
        audioSessionMode: 'default',
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        configureAudioSession: true,
      ),
      missedCallNotification: const NotificationParams(
        showNotification: true,
        subtitle: 'Missed call',
      ),
    );

    final active = await FlutterCallkitIncoming.activeCalls();
    if (active.isEmpty) {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    }
  }

  if (type == 'call_terminated') {
    final callId = message.data['call_id'] ?? '';
    // ✅ iOS: UUID se end karo (stored tha)
    // ✅ Android: original callId se end karo
    final id = prefs.getString('pending_callkit_id') ?? callId;
    if (id.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(id);
    }
    await _clearCallPrefs(prefs);
  }

  if (type == 'new_message' || message.notification != null) {
    debugPrint("📩 Background message received!");
    
    // Yahan aapko ek flag set karna hai ki "Naya message aaya hai, list refresh karo"
    await prefs.setBool('has_new_messages_to_refresh', true);
  }
}

// ============================================
// OPEN CALL SCREEN (global helper)
// ============================================
void openCallScreen({
  required WhatsAppCallingService service,
  required String callerName,
  required String callerNumber,
  required String sdp,
  required String callId,
}) {
  if (_isCallScreenOpen) return;
  _isCallScreenOpen = true;

  Get.to(
    () => IncomingCallScreen(
      callingService: service,
      callerName: callerName,
      callerNumber: callerNumber,
      pendingSdp: sdp,
      pendingCallId: callId,
    ),
  )?.then((_) => _isCallScreenOpen = false);
}

// ============================================
// PREFS CLEANUP HELPER
// ============================================
Future<void> _clearCallPrefs(SharedPreferences prefs) async {
  await prefs.remove('pending_call_id');
  await prefs.remove('pending_call_session');
  await prefs.remove('pending_caller_name');
  await prefs.remove('pending_caller_number');
  await prefs.remove('pending_callkit_id');
  await prefs.remove('pending_from_user_id');
  debugPrint('🧹 Call preferences cleared');
}

// ============================================
// GLOBAL CALL LISTENER INIT
// ============================================
Future<void> _initGlobalCalling() async {
  final prefs = await SharedPreferences.getInstance();

  final userId = prefs.getInt('user_id') ?? 0;
  final adminId = prefs.getInt('admin_id') ?? 0;
  final apiKey = prefs.getString('business_api_key') ?? '';

  if (userId == 0 || apiKey.isEmpty) return;

  await GlobalCallListenerService.instance.initialize(
    userId: userId,
    adminId: adminId,
    businessApiKey: apiKey,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Lifecycle observer — dono platforms ke liye
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission();

  if (Platform.isIOS) {
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    print('🔑 Startup APNS token: $apnsToken');
  }

  // ✅ CallKit notification permission
  await FlutterCallkitIncoming.requestNotificationPermission({
    'title': 'Notification permission',
  });

  // ✅ Android: full intent permission (lock screen pe call dikhane ke liye)
  await FlutterCallkitIncoming.requestFullIntentPermission();

  // ✅ Android file mein tha — CallKit events setup
  WhatsAppCallingConfig.setupCallKitEvents();

  await _initGlobalCalling();
  WhatsAppCallingConfig.initMethodChannel();

  runApp(const MyApp());
}

// ============================================
// INITIALIZE CALL LISTENER (delayed)
// ============================================
Future<void> _initializeCallListener() async {
  await Future.delayed(const Duration(seconds: 2));
  await WhatsAppCallingConfig.initializeCallListener();
}

// ============================================
// MY APP — StatefulWidget
// ✅ iOS: deep link + _checkInitialCall support
// ✅ Android: onReady callbacks bhi work karenge
// ============================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkInitialCall();
  }

  // ✅ App start pe pending call check karo
  // Background se accept karne ke baad app foreground aata hai — yahan handle karo
  Future<void> _checkInitialCall() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final prefs = await SharedPreferences.getInstance();
    final callId = prefs.getString('pending_call_id');
    final session = prefs.getString('pending_call_session');

    if (callId == null || session == null) {
      debugPrint('🚫 No pending call data');
      return;
    }

    debugPrint('📞 Pending call found: $callId');

    // ✅ Active calls check
    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    debugPrint('📞 Active Calls on start: ${activeCalls.length}');

    if (activeCalls.isEmpty) {
      debugPrint('🚫 No active call — clearing prefs');
      await _clearCallPrefs(prefs);
      return;
    }

    // #changedWithJClaude — use initializeCallListener (reads userId from GetStorage)
    // instead of _initGlobalCalling (reads from SharedPreferences, returns if userId=0).
    // In killed state, user_id may not be persisted in SharedPreferences, causing
    // _initGlobalCalling to silently no-op and leaving service=null, which meant
    // setPendingCall() was never called and hasActivePendingCall stayed false.
    await WhatsAppCallingConfig.initializeCallListener();

    // ✅ Session parse karo
    String sdpOffer = '';
    try {
      final sessionMap = jsonDecode(session);
      sdpOffer = sessionMap['sdp'] ?? '';
    } catch (e) {
      debugPrint('❌ Session parse error: $e');
      await _clearCallPrefs(prefs);
      return;
    }

    if (sdpOffer.isEmpty) {
      debugPrint('❌ SDP empty — clearing');
      await _clearCallPrefs(prefs);
      return;
    }

    final callerName = prefs.getString('pending_caller_name') ?? 'Unknown';
    final callerNumber = prefs.getString('pending_caller_number') ?? '';

    // ✅ Service mein pending call set karo
    final service = GlobalCallListenerService.instance.service;
    if (service != null) {
      service.setPendingCall(callId: callId, sdp: sdpOffer);
      service.currentPhoneNumber = callerNumber;
      service.currentCallerName = callerName;
      service.isOutgoingCall = false;
      debugPrint('✅ setPendingCall done in _checkInitialCall (hasActivePendingCall=${service.hasActivePendingCall})');
    } else {
      debugPrint('⚠️ service still null after initializeCallListener — will rely on prefs recovery in _initCall');
    }

    // ✅ Pending navigation set karo
    final userId = await WhatsAppCallingConfig.getUserId();
    final adminId = await WhatsAppCallingConfig.getAdminId();
    final apiKey = await WhatsAppCallingConfig.getBusinessApiKey();
    final avatar =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(callerName)}&background=075E54&color=fff&size=200&rounded=true';

    WhatsAppCallingConfig.storePendingNavigation({
      'userId': userId,
      'adminId': adminId,
      'apiKey': apiKey,
      'callerNumber': callerNumber,
      'callerName': callerName,
      'avatar': avatar,
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!_isCallScreenOpen) {
      WhatsAppCallingConfig.handlePendingCallNavigation();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GetGabs',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      navigatorObservers: [routeObserver],
      getPages: AppPage.list,
      builder: EasyLoading.init(),
      onReady: () {
        debugPrint('✅ App onReady');
        _initializeCallListener();
        WhatsAppCallingConfig.handlePendingCallNavigation();
      },
    );
  }
}

// ============================================
// EASY LOADING CONFIG
// ============================================
void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorType = EasyLoadingIndicatorType.dualRing
    ..backgroundColor = AppTheme.appThemeColor
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskColor = Colors.white
    ..textStyle = const TextStyle(
        fontSize: 16.0, color: Colors.white, fontWeight: FontWeight.w500)
    ..dismissOnTap = false;
}

void showLoading() {
  EasyLoading.show(
      status: 'Loading...',
      maskType: EasyLoadingMaskType.black,
      dismissOnTap: false);
}

void hideLoading() => EasyLoading.dismiss();
