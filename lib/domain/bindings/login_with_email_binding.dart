import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';


class LoginWithEmailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginWithEmailController>(
      () => LoginWithEmailController(),
    );
  }
}