import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:getgabs/domain/bindings/dashboard_binding.dart';
import 'package:getgabs/domain/bindings/login_with_email_binding.dart';
import 'package:getgabs/domain/bindings/splash_screen_binding.dart';
import 'package:getgabs/ui/pages/auth/login_with_email/login_with_email.dart';
import 'package:getgabs/ui/pages/dashboard/dashboard.dart';
import 'package:getgabs/ui/pages/splash_screen/splash_screen.dart';
import '../ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_message_ui/assign_opreator.dart';
import '../ui/pages/dashboard/more/profile/profile.dart';
import 'app_route.dart';

class AppPage {
  AppPage._();

  static const INITIAL = AppRoute.splash;

  static var list = [
    GetPage(
      name: AppRoute.splash,
      page: () => SplashScreen(),
      binding: SplashBinding(),
    ),

    // GetPage(
    //   name: AppRoute.startScreen,
    //   page: () => const StartScreen(),
    //   // binding: SplashBinding(),
    // ),
    GetPage(
      name: AppRoute.loginWithEmail,
      page: () => LoginWithEmailScreen(),
      binding: LoginWithEmailBinding(),
      //  transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoute.dashboard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoute.assignOpreator,
      page: () => AssignOperatorScreen(),

      // transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoute.profileDetailsPage,
      page: () => ProfileScreen(),

      // transition: Transition.rightToLeft,
    ),

    // GetPage(
    //   name: AppRoute.messagesPage,
    //   page: () => MessagesPage(
    //     profile: Get.arguments['profile'],
    //     profileWaKey: Get.arguments['profileWaKey'],
    //   ),
    //   binding: MessagesPageBinding(),
    // ),
    // GetPage(
    //   name: AppRoute.messagesPage,
    //   page: () => MessagesPage(),
    //   binding: DashboardBinding(),
    // )
    // GetPage(
    //   name: AppRoute.loginWithMobile,
    //   page: () => LoginWithMobileOTPPage(),
    //   binding: LoginWithMobileBinding(),
    // ),
    // GetPage(
    //     name: AppRoute.forgetPasswordScreen,
    //     page: () => ForgetPasswordPage(),
    //     binding: ForgotPasswordBinding()),
    // GetPage(
    //   name: AppRoute.mobileLoginVerfication,
    //   page: () => LoginOtpVerificationPage(),
    //   binding: LoginOtpVerificationBinding(),
    // ),
    // GetPage(
    //   name: AppRoute.signupScreen,
    //   page: () => Registrationpage(),
    //   binding: RegistrationpageBinding(),
    // ),
    // GetPage(
    //   name: AppRoute.registrationVerification,
    //   page: () => OtpVerificationPage(),
    //   binding: registrationVerificationBinding(),
    // ),
    // GetPage(
    //   name: AppRoute.profileDetailsPage,
    //   page: () => ProfileDetailsPage(),
    //   binding: ProfileDetailsPageBinding(),
    //   // transition: Transition.rightToLeft,
    // ),
    // GetPage(
    //   name: AppRoute.updateProfilePage,
    //   page: () => UpdateProfileDetailPage(),
    //   binding: UpdateProfileDetailBinding(),
    // ),
  ];
}
