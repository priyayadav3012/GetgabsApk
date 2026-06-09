import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/splash_screen/splash_screen_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashScreenController>(
      () => SplashScreenController(),
    );
  }
}
