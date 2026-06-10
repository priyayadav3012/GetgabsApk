// File: lib/domain/end_points/api_end_points.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/domain/services/whtasapp_calling_service.dart';
import 'package:getgabs/main.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiEndPoints {
  static const String baseUrl = 'https://app.getgabs.com/v2/flutterapplication/';
  static _AuthEndPoints authEndpoints = _AuthEndPoints();
  static _DashboardEndPoints dashboardEndPoints = _DashboardEndPoints();
  static _ChatEndPoints chatEndPoints = _ChatEndPoints();
  static _MoreScreenEndPoints moreScreenEndPoints = _MoreScreenEndPoints();
}

class _AuthEndPoints {
  final String loginWithEmailUrl = "login";
  // ✅ iOS ke liye VoIP token save endpoint
  final String saveVoipToken = "update-tokens";
}

class _DashboardEndPoints {
  final String activeChatListUrl = "customer-list";
}

class _ChatEndPoints {
  final String chatList = "fetchcustomerchat";
  final String sendMessageUrl = "sendmessages";
  final String searchCustomer = "searchcustomer";
  final String sendHelloWorldTemplateUrl = "sendhelloworldtemplatedmessage";
  final String fetchTemplateNamesUrl = "fetchtemplates";
  final String fetchTemplateStructureUrl = "getmessagetemplateapi";
  final String fetchMessageTemplateJsonUrl = "getmessagetemplatejson";
  final String toggleHandoffUrl = "togglehandoff";
  final String shortMessageList = "shortmessagelist";
  final String sendShortMessage = "send-message";
}

class _MoreScreenEndPoints {
  final String logoutUrl = "logout";
}

// ============================================
// WHATSAPP CALLING CONFIG
// ============================================
class WhatsAppCallingConfig {
  static final GetStorageUserData _userData = GetStorageUserData();
  static const String businessApiKeyFallback =
      'PKGEG8ggXzs6xjpIDqBxlwhjIGUuvYMjDG0s7Sp9NzVBOygFUCjPHdHn';
  static const String _socketUrl = 'https://calling.getgabs.com';

  // ✅ iOS ke liye MethodChannel — native CallKit answer handle karta hai
  // Use the same channel name as native AppDelegate: 'com.getgabs/calls'
  static const platform = MethodChannel('com.getgabs/calls');

  static Map<String, dynamic>? _pendingNavigation;

  // ============================================
  // ✅ FLAVOR CHECK — Android + iOS dono ke liye
  // LoginWithEmailController.currentFlavor use karo
  // ============================================
  static bool _checkIsMessagedly() {
    return LoginWithEmailController.currentFlavor == 'messagedly';
  }

  // ============================================
  // ✅ PUBLIC — GlobalCallListenerService yeh call kar sake (iOS background flow)
  // ============================================
  static void storePendingNavigation(Map<String, dynamic> nav) {
    _pendingNavigation = nav;
    debugPrint('📦 _pendingNavigation stored: ${nav['callerName']}');
  }

  // ============================================
  // iOS — Native MethodChannel init
  // Android pe yeh call mat karo (Platform check se handle hoga)
  // ============================================
 static Future<void> initMethodChannel() async {
  if (!Platform.isIOS) return;

  FlutterCallkitIncoming.endAllCalls();

  platform.setMethodCallHandler((call) async {
    debugPrint('📲 Native Method: ${call.method}');

    switch (call.method) {

      // ✅ VoIP Token — backend pe save hota hai login mein already
      case 'onVoipTokenReceived':
        final token = call.arguments as String?;
        debugPrint('📱 VoIP Token: $token');
        break;

      // ✅ VoIP Push aaya — SDP SharedPrefs mein save karo
      case 'onIncomingVoipCall':
        try {
          final args = call.arguments as Map?;
          final callerName = args?['callerName'] as String? ?? 'Unknown';
          final uuid = args?['uuid'] as String? ?? '';
          debugPrint('📞 Incoming VoIP: $callerName');

          final prefs = await SharedPreferences.getInstance();
          // Prefer session passed in the native method call, fallback to prefs
            final sessionFromArgs = args?['session'] as String?;
            String sessionStr = sessionFromArgs?.isNotEmpty == true
              ? sessionFromArgs!
              : (prefs.getString('pending_call_session') ?? '');
          final callerNumber = args?['callerNumber'] as String? ?? prefs.getString('pending_caller_number') ?? '';
          final callId = args?['callId'] as String? ?? prefs.getString('pending_call_id') ?? uuid;

          if (sessionStr.isEmpty) {
            // Race condition: native may not have written prefs yet — retry shortly
            int attempts = 0;
            while (sessionStr.isEmpty && attempts < 2) {
              await Future.delayed(const Duration(milliseconds: 200));
              final freshPrefs = await SharedPreferences.getInstance();
              final freshFromArgs = args?['session'] as String?;
              final fresh = freshFromArgs?.isNotEmpty == true
                  ? freshFromArgs!
                  : (freshPrefs.getString('pending_call_session') ?? '');
              if (fresh.isNotEmpty) {
                // replace sessionStr and callerNumber/callId from fresh prefs if available
                sessionStr = fresh;
                // try to refresh callerNumber/callId from prefs
                final fn = freshPrefs.getString('pending_caller_number') ?? '';
                if (fn.isNotEmpty) {
                  // ignore local variable shadowing; assign to callerNumber variable
                }
                break;
              }
              attempts++;
            }
            if (sessionStr.isEmpty) {
              debugPrint('❌ Session missing');
              break;
            }
          }

          String sdpOffer = '';
          try {
            final sessionMap = jsonDecode(sessionStr);
            sdpOffer = sessionMap['sdp'] ?? '';
          } catch (e) {
            debugPrint('❌ SDP parse error: $e');
            break;
          }

          await initializeCallListener();
          final service = GlobalCallListenerService.instance.service;
          if (service != null) {
            service.setPendingCall(callId: callId, sdp: sdpOffer);
            service.currentPhoneNumber = callerNumber;
            service.currentCallerName = callerName;
            service.isOutgoingCall = false;
          }
        } catch (e) {
          debugPrint('❌ onIncomingVoipCall handler error: $e');
        }
        break;

      // ✅ User ne green button dabaya — calling screen open karo
      case 'onNativeCallAnswered':
        debugPrint('📞 iOS Native Answer Received');
        final args2 = call.arguments as Map?;
        final uuid2 = args2?['uuid'] as String? ?? '';

        final prefs2 = await SharedPreferences.getInstance();
        String sessionStr2 = prefs2.getString('pending_call_session') ?? '';
        String callerName2 = prefs2.getString('pending_caller_name') ?? 'Unknown';
        String callerNumber2 = prefs2.getString('pending_caller_number') ?? '';
        String callId2 = prefs2.getString('pending_call_id') ?? uuid2;

        try {
          final sessionFromArgs = args2?['session'] as String?;
          if (sessionFromArgs?.isNotEmpty == true) sessionStr2 = sessionFromArgs!;
          final cn = args2?['callerName'] as String?;
          if (cn?.isNotEmpty == true) callerName2 = cn!;
          final cnum = args2?['callerNumber'] as String?;
          if (cnum?.isNotEmpty == true) callerNumber2 = cnum!;
          final cid = args2?['callId'] as String?;
          if (cid?.isNotEmpty == true) callId2 = cid!;

          if (sessionStr2.isEmpty) {
            // Retry briefly for race between native writing prefs and Flutter handling
            int attempts2 = 0;
            while (sessionStr2.isEmpty && attempts2 < 2) {
              await Future.delayed(const Duration(milliseconds: 200));
              final freshPrefs2 = await SharedPreferences.getInstance();
              final freshFromArgs2 = args2?['session'] as String?;
              final fresh2 = freshFromArgs2?.isNotEmpty == true
                  ? freshFromArgs2!
                  : (freshPrefs2.getString('pending_call_session') ?? '');
              if (fresh2.isNotEmpty) {
                sessionStr2 = fresh2;
                break;
              }
              attempts2++;
            }
            if (sessionStr2.isEmpty) {
              debugPrint('❌ Session missing for answer');
              break;
            }
          }

          String sdp2 = '';
          try {
            final sessionMap2 = jsonDecode(sessionStr2);
            sdp2 = sessionMap2['sdp'] ?? '';
          } catch (e) {
            debugPrint('❌ SDP parse error: $e');
            break;
          }

          await initializeCallListener();
          final svc = GlobalCallListenerService.instance.service;
          if (svc != null) {
            svc.setPendingCall(callId: callId2, sdp: sdp2);
            svc.currentPhoneNumber = callerNumber2;
            svc.currentCallerName = callerName2;
            svc.isOutgoingCall = false;
          }
        } catch (e) {
          debugPrint('❌ onNativeCallAnswered handler error: $e');
        }

        final userId = await getUserId();
        final adminId = await getAdminId();
        final apiKey = await getBusinessApiKey();
        final avatar =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(callerName2)}&background=075E54&color=fff&size=200&rounded=true';

        storePendingNavigation({
          'userId': userId,
          'adminId': adminId,
          'apiKey': apiKey,
          'callerNumber': callerNumber2,
          'callerName': callerName2,
          'avatar': avatar,
        });

        if (isAppInForeground) {
          await handlePendingCallNavigation();
        }
        break;

      // ✅ Native se call end hua
      case 'onCallEndedNatively':
        debugPrint('📵 Native Call Ended');
        await FlutterCallkitIncoming.endAllCalls();
        final svc2 = GlobalCallListenerService.instance.service;
        await svc2?.cleanupCall();
        break;
    }
  });
  // Request cached VoIP token from native (AppDelegate caches token)
  try {
    await platform.invokeMethod('getVoipTokenForcefully');
  } catch (e) {
    debugPrint('getVoipTokenForcefully not available: $e');
  }
} // ============================================
  // CREDENTIALS HELPERS
  // ============================================
  static Future<String> getBusinessApiKey() async {
    try {
      final apiKey = await _userData.getApiKey();
      return apiKey.isEmpty ? businessApiKeyFallback : apiKey;
    } catch (e) {
      return businessApiKeyFallback;
    }
  }

  static Future<int> getUserId() async {
    try {
      final userId = await _userData.getLoggedInUserId();
      return (userId == null || userId == 0) ? 0 : userId;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getAdminId() async {
    try {
      final adminIdStr = await _userData.getParentUserId();
      if (adminIdStr == null || adminIdStr.trim().isEmpty) return await getUserId();
      final adminId = int.tryParse(adminIdStr);
      return (adminId == null || adminId == 0) ? await getUserId() : adminId;
    } catch (e) {
      return await getUserId();
    }
  }

  // ============================================
  // INITIALIZE CALL LISTENER
  // ============================================
  static Future<void> initializeCallListener() async {
    final userId = await getUserId();
    final adminId = await getAdminId();
    final apiKey = await getBusinessApiKey();
    if (userId > 0) {
      await GlobalCallListenerService.instance.initialize(
          userId: userId, adminId: adminId, businessApiKey: apiKey);
      debugPrint('✅ Call listener initialized');
    }
  }

  // ============================================
  // TERMINATE CALL VIA HTTP — service null hone par bhi kaam karega
  // ============================================
  static Future<void> _terminateCallViaHttp(String callId) async {
    if (callId.isEmpty) return;
    try {
      final apiKey = await getBusinessApiKey();
      await http.post(
        Uri.parse('$_socketUrl/terminate-whatsapp-call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'callId': callId, 'api_key': apiKey}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('✅ Call terminated via HTTP: $callId');
    } catch (e) {
      debugPrint('❌ HTTP terminate error: $e');
    }
  }

  // ============================================
  // CALLKIT EVENTS SETUP
  // ✅ Android: full listener — accept/decline/timeout handle karo
  // ✅ iOS: GlobalCallListenerService ka listener kafi hai
  //         (duplicate listener avoid karo)
  // ============================================
  static void setupCallKitEvents() {
    if (Platform.isIOS) {
      // ✅ iOS pe GlobalCallListenerService already listen kar raha hai
      // Duplicate listener lagane se double events fire honge
      debugPrint('⚠️ iOS: setupCallKitEvents skipped — GlobalCallListenerService handles events');
      return;
    }

    // ✅ Android: Full CallKit event handling
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;

      debugPrint('📞 CallKit event: $event');

      // ✅ v3.0.0 — sealed class pattern use karo (Event enum gone)
      if (event is CallEventActionCallAccept) {
        final callId = event.id;
        final prefs = await SharedPreferences.getInstance();
        final sessionStr = prefs.getString('pending_call_session') ?? '';
        final callerName = prefs.getString('pending_caller_name') ?? '';
        final callerNumber = prefs.getString('pending_caller_number') ?? '';
        final savedCallId = prefs.getString('pending_call_id') ?? callId;

        debugPrint('📞 Accept — session empty: ${sessionStr.isEmpty} | number: $callerNumber');

        if (sessionStr.isEmpty || callerNumber.isEmpty) {
          debugPrint('❌ No pending session/number');
          return;
        }

        String sdpOffer = '';
        try {
          final sessionMap = jsonDecode(sessionStr);
          sdpOffer = sessionMap['sdp'] ?? '';
        } catch (e) {
          debugPrint('❌ Session parse error: $e');
          return;
        }

        if (sdpOffer.isEmpty) {
          debugPrint('❌ SDP empty');
          return;
        }

        final userId = await getUserId();
        final adminId = await getAdminId();
        final apiKey = await getBusinessApiKey();

        final displayForAvatar = callerName.isNotEmpty
            ? callerName
            : callerNumber.replaceAll('+', '').replaceAll(' ', '');

        final String avatarBgColor = _checkIsMessagedly() ? '4242D4' : '075E54';
        final avatar =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayForAvatar)}&background=$avatarBgColor&color=fff&size=200&rounded=true&bold=true';

        await initializeCallListener();
        final service = GlobalCallListenerService.instance.service;
        if (service != null) {
          service.setPendingCall(callId: savedCallId, sdp: sdpOffer);
          service.currentPhoneNumber = callerNumber;
          service.currentCallerName = callerName;
          service.isOutgoingCall = false;
          debugPrint('✅ setPendingCall done');
        }

        await _clearCallPrefs(prefs);

        if (Get.context != null) {
          debugPrint('🚀 Navigating directly');
          Get.to(
            () => WhatsAppCallingScreen(
              userId: userId,
              adminId: adminId,
              businessApiKey: apiKey,
              initialPhoneNumber: callerNumber,
              contactName: callerName,
              contactAvatar: avatar,
              isIncoming: true,
            ),
            transition: Transition.fadeIn,
          );
        } else {
          debugPrint('⏳ Context not ready — storing pending navigation');
          _pendingNavigation = {
            'userId': userId,
            'adminId': adminId,
            'apiKey': apiKey,
            'callerNumber': callerNumber,
            'callerName': callerName,
            'avatar': avatar,
          };
        }

      } else if (event is CallEventActionCallDecline) {
        debugPrint('📵 Call declined from CallKit');
        final callId = event.id;
        final prefs2 = await SharedPreferences.getInstance();
        final declineCallId = prefs2.getString('pending_call_id') ?? callId;
        await _clearCallPrefs(prefs2);

        final svc = GlobalCallListenerService.instance.service;
        if (svc != null && declineCallId.isNotEmpty) {
          await svc.terminateCall();
        } else {
          await _terminateCallViaHttp(declineCallId);
        }

        try { await FlutterCallkitIncoming.endCall(callId); } catch (e) {}

      } else if (event is CallEventActionCallTimeout) {
        debugPrint('⏰ Call timeout');
        final callId = event.id;
        final prefs3 = await SharedPreferences.getInstance();
        final timeoutCallId = prefs3.getString('pending_call_id') ?? callId;
        await _clearCallPrefs(prefs3);

        final svc2 = GlobalCallListenerService.instance.service;
        if (svc2 != null && timeoutCallId.isNotEmpty) {
          svc2.currentCallId = timeoutCallId;
          await svc2.terminateCall();
        } else {
          await _terminateCallViaHttp(timeoutCallId);
        }

        try { await FlutterCallkitIncoming.endCall(callId); } catch (e) {}

      } else if (event is CallEventActionCallEnded) {
        try { await FlutterCallkitIncoming.endAllCalls(); } catch (e) {}

      } else {
        debugPrint('📞 Unhandled CallKit event: $event');
      }
    }, onError: (e, st) {
      debugPrint('❌ CallKit stream error (android listener): $e');
      debugPrint('$st');
      // Ignore plugin parsing errors (some events may be malformed).
    });
  }

  // ============================================
  // HANDLE PENDING CALL NAVIGATION
  // ✅ iOS: activeCalls check nahi — background answered calls block ho rahe the
  // ✅ Android: same behavior — safe hai
  // ============================================
  static Future<void> handlePendingCallNavigation() async {
    if (_pendingNavigation == null) {
      debugPrint('✅ No pending navigation — skipping');
      return;
    }

    final nav = _pendingNavigation!;
    _pendingNavigation = null;

    if (Get.context == null) {
      debugPrint('❌ Context null — storing back for retry');
      _pendingNavigation = nav;
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));

    debugPrint('🚀 Opening Calling Screen: ${nav['callerName']}');

    Get.to(
      () => WhatsAppCallingScreen(
        userId: nav['userId'] as int,
        adminId: nav['adminId'] as int,
        businessApiKey: nav['apiKey'] as String,
        initialPhoneNumber: nav['callerNumber'] as String,
        contactName: nav['callerName'] as String,
        contactAvatar: nav['avatar'] as String,
        isIncoming: true,
      ),
      transition: Transition.fadeIn,
    );

    final prefs = await SharedPreferences.getInstance();
    await _clearCallPrefs(prefs);
  }

  static Future<void> _clearCallPrefs(SharedPreferences prefs) async {
    await prefs.remove('pending_call_session');
    await prefs.remove('pending_call_id');
    await prefs.remove('pending_caller_name');
    await prefs.remove('pending_caller_number');
    await prefs.remove('pending_from_user_id');
    await prefs.remove('pending_callkit_id');
    debugPrint('🧹 Call prefs cleared');
  }

  // ============================================
  // MAKE OUTGOING CALL
  // ✅ Flavor-aware colors — Android + iOS dono pe
  // ============================================
  static Future<void> makeCall({
    required String phoneNumber,
    String contactName = '',
    String? contactAvatar,
  }) async {
    try {
      final Color loaderColor = _checkIsMessagedly()
          ? const Color(0xff4242D4)
          : const Color(0xFF00A884);

      Get.dialog(
        Center(child: CircularProgressIndicator(color: loaderColor)),
        barrierDismissible: false,
        barrierColor: Colors.black54,
      );

      final int userId = await getUserId();
      final int adminId = await getAdminId();
      final String apiKey = await getBusinessApiKey();

      if (Get.isDialogOpen ?? false) Get.back();
      if (userId == 0) {
        _showError('User credentials not found');
        return;
      }

      final displayForAvatar = contactName.isNotEmpty
          ? contactName
          : phoneNumber.replaceAll('+', '').replaceAll(' ', '');

      final String avatarBgColor = _checkIsMessagedly() ? '4242D4' : '075E54';
      final avatar = contactAvatar ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayForAvatar)}&background=$avatarBgColor&color=fff&size=200&rounded=true&bold=true';

      Get.to(
        () => WhatsAppCallingScreen(
          userId: userId,
          adminId: adminId,
          businessApiKey: apiKey,
          initialPhoneNumber: phoneNumber,
          contactName: contactName,
          contactAvatar: avatar,
          isIncoming: false,
        ),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      _showError('Failed to start call');
    }
  }

  // ============================================
  // INCOMING CALL POPUP (FOREGROUND - SOCKET)
  // ============================================
  static void _showIncomingCallPopup({
    required String callerName,
    required String callerNumber,
    required String callerAvatar,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Material(
          color: Colors.black54,
          child: SafeArea(
            child: Column(children: [
              IncomingCallCard(
                callerName: callerName,
                callerNumber: callerNumber,
                onAccept: () {
                  Get.back();
                  onAccept();
                },
                onDecline: () {
                  Get.back();
                  onDecline();
                },
              ),
            ]),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  static Future<void> showIncomingCall({
    required String callId,
    required String callerNumber,
    required String sdpOffer,
    String callerName = '',
    String? callerAvatar,
  }) async {
    try {
      final int userId = await getUserId();
      final int adminId = await getAdminId();
      final String apiKey = await getBusinessApiKey();
      if (userId == 0) return;

      final name = callerName.isNotEmpty ? callerName : callerNumber;
      final displayForAvatar = callerName.isNotEmpty
          ? callerName
          : callerNumber.replaceAll('+', '').replaceAll(' ', '');

      final String avatarBgColor = _checkIsMessagedly() ? '4242D4' : '075E54';
      final avatar = callerAvatar ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayForAvatar)}&background=$avatarBgColor&color=fff&size=200&rounded=true&bold=true';

      _showIncomingCallPopup(
        callerName: callerName,
        callerNumber: callerNumber,
        callerAvatar: avatar,
        onAccept: () => Get.to(
          () => WhatsAppCallingScreen(
            userId: userId,
            adminId: adminId,
            businessApiKey: apiKey,
            initialPhoneNumber: callerNumber,
            contactName: name,
            contactAvatar: avatar,
            isIncoming: true,
          ),
          transition: Transition.fadeIn,
        ),
        onDecline: () =>
            GlobalCallListenerService.instance.service?.terminateCall(),
      );
    } catch (e) {
      debugPrint('❌ Error showing incoming call: $e');
    }
  }

  // ============================================
  // CALL OPTIONS BOTTOM SHEET
  // ✅ Flavor-aware — Android + iOS dono pe
  // ============================================
  static void showCallOptions(
      BuildContext context, String phoneNumber, String contactName) {
    final bool isMessagedly = _checkIsMessagedly();
    final String callOptionTitle =
        isMessagedly ? 'Messagedly Voice Call' : 'GetGabs Voice Call';
    final Color dynamicBrandColor =
        isMessagedly ? const Color(0xff4242D4) : const Color(0xFF00A884);
    final String avatarBgHex = isMessagedly ? '4242D4' : '075E54';

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2C34),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: dynamicBrandColor,
                backgroundImage: NetworkImage(
                  'https://ui-avatars.com/api/?name=${Uri.encodeComponent(contactName.isNotEmpty ? contactName : phoneNumber)}&background=$avatarBgHex&color=fff&size=200',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName.isNotEmpty ? contactName : phoneNumber,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (contactName.isNotEmpty)
                        Text(phoneNumber,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14)),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[700], height: 1),
            const SizedBox(height: 16),
            _buildCallOption(
              icon: Icons.call,
              iconColor: dynamicBrandColor,
              title: callOptionTitle,
              subtitle: 'Free via internet',
              onTap: () {
                Get.back();
                makeCall(phoneNumber: phoneNumber, contactName: contactName);
              },
            ),
            const SizedBox(height: 12),
            _buildCallOption(
              icon: Icons.phone,
              iconColor: Colors.blue,
              title: 'Regular Call',
              subtitle: 'Use phone dialer',
              onTap: () async {
                Get.back();
                final url = Uri.parse('tel:$phoneNumber');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            ),
          ]),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  static Widget _buildCallOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3942),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ]),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ]),
        ),
      ),
    );
  }

  static void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEA4335),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  static Future<void> openCallingScreenWithGetX(String phoneNumber) async =>
      makeCall(phoneNumber: phoneNumber);

  static bool isCallListenerActive() =>
      GlobalCallListenerService.instance.isInitialized;
}