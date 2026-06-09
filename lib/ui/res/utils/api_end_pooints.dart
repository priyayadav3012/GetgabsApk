class ApiEndPoints {
  static const String baseUrl = 'https://99pandit.com/wp-json/api/v1/';
  // static final String baseUrl =
  //     'http://pandit.99isolutions.com/wp-json/api/v1/';
  static _AuthEndPoints authEndpoints = _AuthEndPoints();
  static _ProfileEndPoints profileEndPoints = _ProfileEndPoints();
  static _WalletEndPoints walletEndPoints = _WalletEndPoints();
  static _PaymentEndPoints paymentEndPoints = _PaymentEndPoints();
  static _LeadEndPoints leadEndPoints = _LeadEndPoints();
}

class _AuthEndPoints {
  // final String registerEmail = 'authaccount/registration';
  // final String loginEmail = 'authaccount/login';
  final String stateListApi = 'state-list';
  final String cityListApi = 'city-list';
  final String loginWithMobileNumberUrl = "mobile-login";
  final String verifyLoginOtpUrl = "verify-otp-client";
  final String resendLoginOtpUrl = "resend-otp-login";
  final String forgotPasswordUrl = "forget-password";

  final String loginWithEmailUrl = "login";
  final String signUpUrl = "register";
  final String verifyOtpUrl = "verify-otp";
  final String resendOtpUrl = "resend-otp";
}

class _ProfileEndPoints {
  final String profileDetailUrl = "profile-detail";
  final String getAllServicesUrl = "service-list";

  final String languagesListUrl = "language-list";
  final String updateProfileUrl = "update-profile";
  
  final String logoutUrl = "logout";
}

class _WalletEndPoints {
  final String rechargeWalletListHistory = "wallet-list";
  final String giftPointList = 'gift-point-list';
}

class _PaymentEndPoints {
  final String getRazorpayOrderId = "wallet-recharge-order";
  final String paymentStatusConformStatus = "wallet-recharge-api";
}

class _LeadEndPoints {
  final String leadListUrl = 'enquiry-list';
  final String acceptedLeadsUrl = 'accepted-leads';
  final String leadAcceptionUrl = 'enquiry-accept';
  final String refreshFcmTokenUrl = 'refresh-fcm-token';

  final String isReceivedNotificationUrl = 'update-received-status';

  final String accountDeletionUrl = 'account-deletion-request';
}
