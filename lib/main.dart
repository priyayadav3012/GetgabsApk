// File: lib/main.dart
// ✅ UNIFIED FILE — Works seamlessly for both Android & iOS with Double Call Protections

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
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/firebase_options.dart';
import 'package:getgabs/routes/app_page.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'domain/services/whtasapp_calling_service.dart';

final _uuid = const Uuid();

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

// ✅ Global tracking state variables
bool isAppInForeground = true;
bool _isCallScreenOpen = false;

// 🔥 CRITICAL: Global cache to block identical duplicate payloads inside identical event loops
final Set<String> _processedCallKitIds = {};

// ============================================
// LIFECYCLE OBSERVER
// ============================================
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isAppInForeground = state == AppLifecycleState.resumed;
    debugPrint(isAppInForeground ? '🟢 FOREGROUND' : '🔴 BACKGROUND');

    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 800), () {
        // Only attempt navigation if call screen isn't already open.
        // onNativeCallAnswered handler already calls handlePendingCallNavigation() immediately;
        // this delayed retry covers the edge case where context wasn't ready then.
        if (!_isCallScreenOpen) {
          WhatsAppCallingConfig.handlePendingCallNavigation();
        }
      });
    }
  }
}

// ============================================
// BACKGROUND FCM HANDLER
// ============================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['type'];
  final prefs = await SharedPreferences.getInstance();

  if (type == 'incoming_call') {
    final callId = message.data['call_id'] ?? '';
    if (callId.isEmpty) return;

    // 🛑 DUP REASON 1 FIX: If identical call ID is being processed by thread worker, dump it!
    if (_processedCallKitIds.contains(callId)) {
      debugPrint('⚠️ [FCM Background] Parallel Duplicate callId blocked natively: $callId');
      return;
    }
    _processedCallKitIds.add(callId);

    final callerName = message.data['caller_name'] ?? 'Unknown';
    final callerNumber = message.data['caller_number'] ?? '';
    final sessionRaw = message.data['session'] ?? '';

    await prefs.setString('pending_call_id', callId);
    await prefs.setString('pending_call_session', sessionRaw);
    await prefs.setString('pending_caller_name', callerName);
    await prefs.setString('pending_caller_number', callerNumber);
    await prefs.setString('pending_from_user_id', message.data['from_user_id'] ?? '');

    final safeId = Platform.isIOS ? _uuid.v4() : callId;
    await prefs.setString('pending_callkit_id', safeId);

    // 🛑 DUP REASON 2 FIX: iOS utilizes Native PushKit (`PKPushRegistry`) inside AppDelegate.swift
    // Invoking `showCallkitIncoming` here on iOS causes a critical native race-condition double UI popup.
    if (Platform.isIOS) {
      debugPrint('🍏 iOS Execution Profile: Bypassing FlutterCallKit invocation. Handled completely by Native PushKit Engine.');
      return;
    }

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
        audioSessionMode: 'videoChat',
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        configureAudioSession: false,
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
    _processedCallKitIds.remove(callId); // Drop memory reference filter track
    
    final id = prefs.getString('pending_callkit_id') ?? callId;
    if (id.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(id);
    }
    await _clearCallPrefs(prefs);
  }

  if (type == 'new_message' || message.notification != null) {
    debugPrint("📩 Background message received!");
    await prefs.setBool('has_new_messages_to_refresh', true);
  }
}

// ============================================
// OPEN CALL SCREEN (Global Thread Guard)
// ============================================
void openCallScreen({
  required WhatsAppCallingService service,
  required String callerName,
  required String callerNumber,
  required String sdp,
  required String callId,
}) {
  // Safe execution toggle wrapper to completely abort screen doubling/stack splits
  if (_isCallScreenOpen) {
    debugPrint('⚠️ UI Collision Guard: openCallScreen dropped execution to prevent layout mirroring.');
    return;
  }
  _isCallScreenOpen = true;

  Get.to(
    () => IncomingCallScreen(
      callingService: service,
      callerName: callerName,
      callerNumber: callerNumber,
      pendingSdp: sdp,
      pendingCallId: callId,
    ),
  )?.then((_) {
    _isCallScreenOpen = false;
    _processedCallKitIds.remove(callId); // Safely drop identification checks on pop cleanup
  });
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

  WidgetsBinding.instance.addObserver(AppLifecycleObserver());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission();

  if (Platform.isIOS) {
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    print('🔑 Startup APNS token: $apnsToken');
  }

  await FlutterCallkitIncoming.requestNotificationPermission({
    'title': 'Notification permission',
  });

  await FlutterCallkitIncoming.requestFullIntentPermission();

  WhatsAppCallingConfig.setupCallKitEvents();

  await _initGlobalCalling();
  WhatsAppCallingConfig.initMethodChannel();

  runApp(const MyApp());
}

// ============================================
// INITIALIZE CALL LISTENER
// ============================================
Future<void> _initializeCallListener() async {
  await Future.delayed(const Duration(seconds: 2));
  await WhatsAppCallingConfig.initializeCallListener();
}

// ============================================
// MY APP — Main Core Container
// ============================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialCheckExecuted = false;

  @override
  void initState() {
    super.initState();
    _checkInitialCall();
  }

  // App start execution sequencing framework
  Future<void> _checkInitialCall() async {
    // Prevent duplicated checks when lifecycle changes match boot loops
    if (_initialCheckExecuted) return;
    _initialCheckExecuted = true;

    await Future.delayed(const Duration(milliseconds: 1500));

    final prefs = await SharedPreferences.getInstance();
    final callId = prefs.getString('pending_call_id');
    final session = prefs.getString('pending_call_session');

    if (callId == null || session == null) {
      debugPrint('🚫 No pending cold boot call data found.');
      return;
    }

    // 🛑 DUP REASON 3 FIX: If navigation routing pipeline is active, instantly drop redundant lookups
    if (_isCallScreenOpen) {
      debugPrint('⚠️ [Boot Block] UI layer configuration active. Aborting multi-navigation stack initialization.');
      return;
    }

    debugPrint('📞 Cold boot pending call identified: $callId');

    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    debugPrint('📞 Active OS Level Calls monitored: ${activeCalls.length}');

    // On iOS, PushKit calls are shown via native CallKit (CallManager), NOT via
    // FlutterCallkitIncoming. activeCalls() only tracks Flutter-reported calls,
    // so it returns empty even when a real native call is ringing. We must also
    // check the native UUID before concluding the prefs are stale.
    bool hasNativeIosCall = false;
    if (Platform.isIOS && activeCalls.isEmpty) {
      try {
        final nativeUUID = await WhatsAppCallingConfig.platform
            .invokeMethod<String?>('getNativeCallUUID');
        hasNativeIosCall = nativeUUID != null && nativeUUID.isNotEmpty;
        if (hasNativeIosCall) {
          debugPrint('📞 Native iOS CallKit call active (UUID: $nativeUUID) — preserving prefs.');
        }
      } catch (_) {}
    }

    if (activeCalls.isEmpty && !hasNativeIosCall) {
      debugPrint('🚫 Stale/Ghost Call data discovered without OS active references — flushing.');
      await _clearCallPrefs(prefs);
      return;
    }

    await _initGlobalCalling();

    String sdpOffer = '';
    try {
      final sessionMap = jsonDecode(session);
      sdpOffer = sessionMap['sdp'] ?? '';
    } catch (e) {
      debugPrint('❌ Session validation parsing failed: $e');
      await _clearCallPrefs(prefs);
      return;
    }

    if (sdpOffer.isEmpty) {
      await _clearCallPrefs(prefs);
      return;
    }

    final callerName = prefs.getString('pending_caller_name') ?? 'Unknown';
    final callerNumber = prefs.getString('pending_caller_number') ?? '';

    final service = GlobalCallListenerService.instance.service;
    if (service != null) {
      service.setPendingCall(callId: callId, sdp: sdpOffer);
      service.currentPhoneNumber = callerNumber;
      service.currentCallerName = callerName;
      service.isOutgoingCall = false;
    }

    final userId = await WhatsAppCallingConfig.getUserId();
    final adminId = await WhatsAppCallingConfig.getAdminId();
    final apiKey = await WhatsAppCallingConfig.getBusinessApiKey();
    final avatar = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(callerName)}&background=075E54&color=fff&size=200&rounded=true';

    WhatsAppCallingConfig.storePendingNavigation({
      'userId': userId,
      'adminId': adminId,
      'apiKey': apiKey,
      'callerNumber': callerNumber,
      'callerName': callerName,
      'avatar': avatar,
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!_isCallScreenOpen) {
      WhatsAppCallingConfig.handlePendingCallNavigation();
    }
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
        debugPrint('✅ Unified Application Layer Engine Ready.');
        _initializeCallListener();
        
        // 🛑 DUP REASON 4 FIX: Removed the redundancy caller check from here. 
        // `_checkInitialCall()` processes navigation inside its async execution sequence cleanly.
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
    ..textStyle = const TextStyle(fontSize: 16.0, color: Colors.white, fontWeight: FontWeight.w500)
    ..dismissOnTap = false;
}

void showLoading() {
  EasyLoading.show(status: 'Loading...', maskType: EasyLoadingMaskType.black, dismissOnTap: false);
}

void hideLoading() => EasyLoading.dismiss();