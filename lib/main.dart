// File: lib/main.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:getgabs/firebase_options.dart';
import 'package:getgabs/routes/app_page.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/services/whtasapp_calling_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ✅ Dono platforms ke liye global flags
bool isAppInForeground = true;

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
      Future.delayed(const Duration(milliseconds: 100), () {
        // Primary path: open pending incoming call screen (new call arriving).
        WhatsAppCallingConfig.handlePendingCallNavigation();

        final svc = GlobalCallListenerService.instance.service;
        // Gate on callAccepted (NOT isCallActive): an incoming call that is still
        // ringing has isCallActive=true but callAccepted=false. Recovery re-pushes
        // WhatsAppCallingScreen, whose _initCall auto-calls answerCall() when a
        // pending call exists — so gating on isCallActive would auto-answer a
        // ringing call just because the user opened the app. Only an already-
        // answered, in-progress call needs its screen restored.
        // Also gate on !isCleaningUp: during teardown callAccepted still reads
        // true for a few seconds (HTTP terminate + native endCall run before
        // cleanupCall clears it), which would re-push a screen for an ending call.
        if (svc != null && svc.callAccepted && !svc.isCleaningUp) {
          // Audio re-activation: restore WebRTC audio in case CXProvider
          // didActivate didn't re-fire after a GSM interruption.
          const MethodChannel('com.getgabs/calls')
              .invokeMethod<void>('activateWebRTCAudio')
              .catchError((e) {
            debugPrint('⚠️ activateWebRTCAudio on resume error: $e');
          });

          // Active-call recovery: if an ongoing call exists but the call
          // screen is no longer on the navigation stack (e.g. wiped by a
          // stack-clearing navigation or lost under memory pressure),
          // re-push it. Shares the guarded implementation with the
          // routingCallback self-heal in GetMaterialApp.
          WhatsAppCallingConfig.restoreCallScreenIfActive();
        }
      });
    } else if (state == AppLifecycleState.inactive) {
      // GSM call arriving or multi-tasking swipe. Audio continuity is handled
      // by CallManager.provider(_:didDeactivate:) setting isAudioEnabled=false.
      // We log here for diagnostics and restore audio in the 'resumed' branch above.
      debugPrint('⚠️ App inactive — possible audio interruption (GSM or backgrounding)');
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

    // iOS: store the server-supplied uuid (same v5 UUID the VoIP push carries so
    // AppDelegate and this handler agree on the same CallKit UUID).  Do NOT call
    // FlutterCallkitIncoming.showCallkitIncoming() — native CallManager owns the
    // CallKit UI on iOS (see C-2).
    if (Platform.isIOS) {
      final serverUuid = message.data['uuid'] ?? callId;
      await prefs.setString(
        'pending_callkit_id',
        normalizeCallKitId(serverUuid),
      );
      return;
    }

    // Android path: flutter_callkit_incoming owns the CallKit-equivalent UI.
    final safeId = normalizeCallKitId(callId);
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
      appName: AppTheme.currentFlavor == 'messagedly'
          ? 'Messagedly'
          : AppTheme.currentFlavor == 'scalewiz'
              ? 'Scalewiz'
              : 'GetGabs',
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
      missedCallNotification: const NotificationParams(
        showNotification: true,
        subtitle: 'Missed call',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
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

  // Request microphone permission immediately on first launch so the system
  // dialog never appears mid-call-setup. On subsequent launches the OS returns
  // instantly (permission already cached), so this adds negligible startup cost.
  await Permission.microphone.request();

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
    await Future.delayed(const Duration(milliseconds: 2500));

    final prefs = await SharedPreferences.getInstance();
    final callId = prefs.getString('pending_call_id');
    final session = prefs.getString('pending_call_session');

    if (callId == null || session == null) {
      debugPrint('🚫 No pending call data');
      return;
    }

    debugPrint('📞 Pending call found: $callId');

    // On iOS, VoIP push calls are owned by the native CallManager (CXProvider).
    // FlutterCallkitIncoming.activeCalls() only tracks calls shown via
    // FlutterCallkitIncoming.showCallkitIncoming() — it always returns empty for
    // VoIP push calls on iOS. Using it as a gate here clears prefs and aborts
    // the recovery flow 1.5 s into the killed-state answer sequence.
    if (!Platform.isIOS) {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      debugPrint('📞 Active Calls on start: ${activeCalls.length}');
      if (activeCalls.isEmpty) {
        debugPrint('🚫 No active call — clearing prefs');
        await _clearCallPrefs(prefs);
        return;
      }
    } else {
      debugPrint('📞 iOS: skipping activeCalls() — VoIP call managed natively by CallManager');
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
      debugPrint(
          '✅ setPendingCall done in _checkInitialCall (hasActivePendingCall=${service.hasActivePendingCall})');
    } else {
      debugPrint(
          '⚠️ service still null after initializeCallListener — will rely on prefs recovery in _initCall');
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

    // handlePendingCallNavigation guards itself with its own _callScreenOpen flag.
    WhatsAppCallingConfig.handlePendingCallNavigation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppTheme.currentFlavor == 'messagedly'
          ? 'Messagedly'
          : AppTheme.currentFlavor == 'scalewiz'
              ? 'Scalewiz'
              : 'GetGabs',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      navigatorObservers: [routeObserver],
      getPages: AppPage.list,
      builder: EasyLoading.init(),
      // Self-heal for the call screen: stack-wiping navigations (splash's
      // Get.offAllNamed(dashboard) during a killed-state launch, logout
      // redirects) destroy the call screen while the call keeps running in
      // the global service. After every navigation settles, restore the
      // screen if an accepted call has no screen. Guarded internally against
      // ringing calls, teardown, and re-entrancy — a no-op in normal routing.
      routingCallback: (routing) {
        WhatsAppCallingConfig.restoreCallScreenIfActive();
      },
      onReady: () {
        debugPrint('✅ App onReady');
        _initializeCallListener();
        // Navigation is handled by _checkInitialCall (killed state) and by
        // onNativeCallAnswered / CallEventActionCallAccept (foreground/background).
        // Calling handlePendingCallNavigation here fires before _checkInitialCall
        // has set _pendingNavigation, making it a no-op, and could fire on stale
        // data if cleanupCall() missed clearing it.
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
