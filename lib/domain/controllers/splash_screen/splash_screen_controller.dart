import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:getgabs/routes/app_route.dart';

class SplashScreenController extends GetxController {
  static SplashScreenController get find => Get.find();
  //change splash screen both the images!!!!!!!!!!!!!!!!!!!!!!
  // UserPreference userPreference = UserPreference();

  final box = GetStorage();
  RxBool animate = false.obs;

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
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      animate.value = true;
      await Future.delayed(const Duration(milliseconds: 5000));
      authentication();
      // Get.toNamed(AppRoute.splash);
    } catch (e) {
      print('Error navigating to DashboardScreen: $e');
    }
  }

  void authentication() {
    var userId = box.read('id');

    if (userId != null) {
      Timer(const Duration(seconds: 1), () {
        Get.offAllNamed(AppRoute.dashboard);
      });
    } else {
      // if (userId == null) {
      Timer(const Duration(seconds: 1), () {
        // Get.offAllNamed(AppRoute.startScreen);
        Get.offAllNamed(AppRoute.loginWithEmail);
        //   Get.to(() => LoginWithEamilPage());
      });
      // }
      //  else {
      //   Timer(const Duration(seconds: 1), () {
      //     Get.to(() => OtpVerificationPage());
      //   });
      // }
    }
  }
}
