import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:getgabs/routes/app_route.dart';
import '../../../main.dart';

class SplashScreenController extends GetxController {
  static SplashScreenController get find => Get.find();
  // Change splash screen both the images if needed.
  // UserPreference userPreference = UserPreference();

  final box = GetStorage();
  RxBool animate = false.obs;
  bool _animationStarted = false;

  @override
  void onInit() {
    super.onInit();
    // Change status bar color
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        // statusBarColor: AppColors.kcPrimaryColor, // Change to your desired color
        ));
    getDeviceToken();
  }

  void getDeviceToken() async {
    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    String? token = await firebaseMessaging.getToken();

    print("device token splash screen:$token");

    // return token ?? 'no_token_available';
  }

  @override
  void onClose() {
    // Reset status bar color when closing the controller
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.onClose();
  }

  Future<void> startAnimation() async {
    if (_animationStarted) return;
    _animationStarted = true;

    try {
      // Flip immediately (post-frame, not delayed) so the logo starts
      // fading in on the very first frame instead of sitting on a blank
      // white Scaffold first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        animate.value = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      authentication();
      // Get.toNamed(AppRoute.splash);
    } catch (e) {
      print('Error navigating to DashboardScreen: $e');
    }
  }

  void authentication() {
    var userId = box.read('id');

    if (userId != null) {
      // Mic/notification permission dialogs — deferred from app startup
      // until the user is confirmed logged in (auto-login case here).
      requestRuntimePermissions();
      Get.offAllNamed(AppRoute.dashboard);
    } else {
      Get.offAllNamed(AppRoute.loginWithEmail);
    }
  }
}
