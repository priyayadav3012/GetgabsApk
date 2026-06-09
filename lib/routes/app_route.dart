
abstract class AppRoute {
  AppRoute._();

  static const splash = _Paths.splash;
  static const startScreen = _Paths.startScreen;
    static const loginWithEmail = _Paths.loginWithEmail;

  static const dashboard = _Paths.dashboard;
  static const loginWithMobile = _Paths.loginWithMobile;
  static const mobileLoginVerfication = _Paths.mobileLoginVerfication;

  static const signupScreen = _Paths.signupScreen;
  static const registrationVerification = _Paths.registrationVerification;
  static const forgetPasswordScreen = _Paths.forgetPasswordScreen;

  static const profileDetailsPage = _Paths.profileDetailsPage;
  static const updateProfilePage = _Paths.updateProfilePage;
  static const homePage = _Paths.homepage;

  static const messagesPage = _Paths.messagesPage;
 static const assignOpreator = _Paths.assignOpreator;


}

abstract class _Paths {
  _Paths._();
  static const splash = '/';
    static const startScreen = '/startScreen';
  static const loginWithEmail = '/loginWithEmail';
  static const dashboard = '/dashboardscreen';
  static const loginWithMobile = '/loginWithMobile';
  static const mobileLoginVerfication = '/loginScreen';

  

  static const signupScreen = '/signupScreen';
  static const registrationVerification = '/registrationVerification';
  static const forgetPasswordScreen = '/forgetPasswordScreen';

  static const profileDetailsPage = '/profileDetailsPage';
  static const updateProfilePage = '/updateProfilepage';

  static const homepage = '/homePage';

  static const messagesPage = '/messagePage';

   static const assignOpreator = '/assignOpreatorPage';



}