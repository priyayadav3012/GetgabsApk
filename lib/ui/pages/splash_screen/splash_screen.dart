import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';

import '../../../domain/controllers/splash_screen/splash_screen_controller.dart';

class SplashScreen extends StatelessWidget {
  SplashScreen({super.key});

  final splashController = Get.put(SplashScreenController());

  @override
  Widget build(BuildContext context) {
    SplashScreenController.find.startAnimation();
    var mediaQuery = MediaQuery.of(context).size;
    return Scaffold(
      // backgroundColor: Colors.white,
      body: Stack(
        children: [
          Obx(
            () => AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: splashController.animate.value ? 1 : 0,
              child: Center(
                child: Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    ImageAssets.getgabsLogoPng,
                    width: mediaQuery.width * 0.7, // Adjust width as needed
                    height: mediaQuery.height * 0.5, // Adjust height as needed
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
