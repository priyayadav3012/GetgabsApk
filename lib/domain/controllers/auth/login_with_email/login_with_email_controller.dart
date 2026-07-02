// File: lib/domain/controllers/auth/login_with_email/login_with_email_controller.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:getgabs/routes/app_route.dart';
import '../../../../main.dart';
import '../../../services/remote_services/remote_auth_service.dart';
import '../../../end_points/api_end_points.dart';

class LoginWithEmailController extends GetxController
    with GetTickerProviderStateMixin {
  // ✅ Flavor — Android + iOS dono ke liye
  static const String currentFlavor =
      String.fromEnvironment('FLUTTER_APP_FLAVOR');

  var isShowPassword = false.obs;
  final emailController = TextEditingController().obs;
  final passwordController = TextEditingController().obs;
  final emailFocusNode = FocusNode();
  var isFocused = false.obs;
  final passwordFocusNodeo = FocusNode();
  final ValueNotifier<bool> obscurePassword = ValueNotifier(true);

  GetStorageUserData userData = GetStorageUserData();
  final FocusNode focusNode = FocusNode();

  // Form
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final emailFocus = FocusNode();
  final pwFocus = FocusNode();
  final obscure = true.obs;

  // Animations
  late final AnimationController blobCtrl;
  late final Animation<double> blobAnim;
  late final AnimationController entryCtrl;

  // ✅ iOS: Native VoIP channel + token
  // Android pe yeh channel exist nahi karta — Platform check se guard kiya hai
  final MethodChannel _customCallChannel =
      const MethodChannel('com.getgabs/calls');
  String? iOSNativeVoipToken;

  final ChatServices chatServices = ChatServices();
  final RemoteAuthService remoteAuthService = RemoteAuthService();
  String name = "";
  RxBool changeButton = false.obs;

  @override
  void onInit() async {
    super.onInit();

    focusNode.addListener(() {
      isFocused.value = focusNode.hasFocus;
    });

    if (Platform.isIOS) {
      _customCallChannel.setMethodCallHandler((call) async {
        if (call.method == 'onVoipTokenReceived') {
          iOSNativeVoipToken = call.arguments.toString();
          print('🚀 VoIP Token: $iOSNativeVoipToken');
        }
      });
    }
    blobCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat(reverse: true);
    blobAnim = CurvedAnimation(parent: blobCtrl, curve: Curves.easeInOut);

    entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..forward();
  }

  @override
  void onClose() {
    blobCtrl.dispose();
    entryCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    emailFocus.dispose();
    pwFocus.dispose();
    super.onClose();
  }

  @override
  void dispose() {
    emailController.value.dispose();
    passwordController.value.dispose();
    emailFocusNode.dispose();
    passwordFocusNodeo.dispose();
    super.dispose();
  }

  void toggleObscure() => obscure.value = !obscure.value;

  void onLogin() {
    if (formKey.currentState!.validate()) {
      loignApi();
    }
  }

  // ============================================
  // GET DEVICE TOKEN
  // ✅ iOS: APNS token pehle wait karo, phir FCM
  // ✅ Android: directly FCM token lo
  // ============================================
  Future<String> getDeviceToken() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;

      if (Platform.isIOS) {
        print('🍏 iOS detected, checking APNS token...');
        String? apnsToken;
        int retryCount = 0;

        while (apnsToken == null && retryCount < 5) {
          try {
            apnsToken = await firebaseMessaging.getAPNSToken();
          } catch (e) {
            print('Error fetching APNS Token: $e');
          }
          if (apnsToken == null) {
            retryCount++;
            print('⏳ APNS Token nahi mila, retry: $retryCount');
            await Future.delayed(const Duration(seconds: 1));
          }
        }

        if (apnsToken == null) {
          print(
              '❌ APNS Token 5 retries ke baad bhi nahi mila — continuing with FCM token if available');
        } else {
          print('✅ APNS Token confirmed: $apnsToken');
        }
      }

      final token = await firebaseMessaging.getToken();
      print('device token: $token');
      return token ?? '';
    } catch (e) {
      print('Error fetching FCM Token: $e');
      return '';
    }
  }

  // ============================================
  // SYNC TOKENS TO SERVER
  // ✅ iOS: FCM + VoIP token dono bhejo
  // ✅ Android: sirf FCM token (VoIP nahi hota Android pe)
  // ============================================
  Future<void> syncDeviceTokensToServer(String userId, String tokenKey) async {
    try {
      final fcmToken = await getDeviceToken();

      if (Platform.isIOS) {
        String? voipToken = iOSNativeVoipToken;
        print('--- iOS TOKEN SYNC ---');
        print('FCM Token: $fcmToken');
        print('VoIP Token: $voipToken');

        if (voipToken == null || voipToken.isEmpty) {
          try {
            print('📡 Requesting cached VoIP token from native iOS side...');
            await _customCallChannel.invokeMethod('getVoipTokenForcefully');
            await Future.delayed(const Duration(milliseconds: 300));
            voipToken = iOSNativeVoipToken;
            print('📡 VoIP token after force request: $voipToken');
          } catch (e) {
            print('Error requesting VoIP token forcefully: $e');
          }
        }

        if (voipToken != null && voipToken.isNotEmpty) {
          final tokenData = {
            'user_id': int.tryParse(userId) ?? 0,
            'fcm_token': fcmToken,
            'voip_token': voipToken,
            'api_key': tokenKey,
          };
          remoteAuthService.saveVoipTokenService(tokenData, tokenKey).then((r) {
            print('Token sync response: $r');
          }).catchError((e) {
            print('Token sync error: $e');
          });
        } else {
          print('⚠️ VoIP token abhi nahi mila — sync skipped');
        }
      } else {
        // ✅ Android: sirf FCM token sync
        print('--- Android TOKEN SYNC ---');
        print('FCM Token: $fcmToken');
        // Android pe voip_token ki zaroorat nahi
      }
    } catch (e) {
      print('Error in token sync: $e');
    }
  }

  // ============================================
  // ANIMATION HELPERS
  // ============================================
  Animation<double> opacity(double from, double to) =>
      Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
          parent: entryCtrl, curve: Interval(from, to, curve: Curves.easeOut)));

  Animation<Offset> offset(double from, double to,
          {Offset start = const Offset(0, 0.22)}) =>
      Tween<Offset>(begin: start, end: Offset.zero).animate(CurvedAnimation(
          parent: entryCtrl, curve: Interval(from, to, curve: Curves.easeOut)));

  // ============================================
  // LOGIN API
  // ✅ Flavor-aware: messagedly → white_label=true
  // ✅ iOS: login ke baad token sync
  // ============================================
  void loignApi() {
    final Map<String, dynamic> data = {
      'username': emailCtrl.text,
      'password': passwordCtrl.text,
    };

    // ✅ Flavor check — dono platforms pe kaam karega
    if (currentFlavor == 'messagedly') {
      data['white_label'] = 'true';
      print('🎯 Flavor: Messagedly — white_label=true');
    } else if (currentFlavor == 'scalewiz') {
      data['white_label'] = 'true';
      print('🎯 Flavor: Scalewiz — white_label=true');
    } else {
      print('🎯 Flavor: GetGabs');
    }

    configLoading();
    showLoading();

    remoteAuthService.loginWithEmailApiService(data).then((value) {
      print(value);
      if (value['status']) {
        EasyLoading.dismiss();
        print('Login successful for flavor: $currentFlavor');

        final extractedApiKey = value['message']['data']['facebook_details']?[0]
                    ?['api_key']
                ?.toString() ??
            '';

        userData
            .userDataStoreInOneShot(
                value['message']['data'], value['message']['data']['id'])
            .then((_) {
          userData.getLoggedInUserId().then((userId) {
            if (userId > 0) {
              // ✅ iOS: VoIP + FCM sync
              // ✅ Android: FCM only (voip skip hoga)
              syncDeviceTokensToServer(userId.toString(), extractedApiKey);
              // Flush any VoIP token that arrived before login credentials
              // were available (race condition at startup).
              if (Platform.isIOS) {
                WhatsAppCallingConfig.flushPendingVoipToken();
              }
            }
            Get.offAllNamed(AppRoute.dashboard);
          });
        });
      } else {
        EasyLoading.showError(value['message']);
      }
    }).onError((error, stackTrace) {
      print('API Error: $error');
    }).whenComplete(() {
      EasyLoading.dismiss();
    });
  }
}
