import 'package:flutter/material.dart';

class ImageAssets {
  // 🕵️‍♂️ Flavor detect karne ke liye line
  static const String currentFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

  //-------------------------- Dynamic Logos (Jo Flavor ke hisab se badlenge) ---------------------------------
  
  static String get getGabsLogoSvg {
    return currentFlavor == 'messagedly'
        ? 'assets/images/messagedly_logo.png' // 🟧 Messagedly ka SVG Logo path
        : 'assets/images/getgabslogo.svg';    // 🟦 GetGabs ka SVG Logo path
  }

  static String get getGabsLogoPng {
    return currentFlavor == 'messagedly'
        ? 'assets/images/messagedly_logo.png' // 🟧 Messagedly ka PNG Logo path
        : 'assets/images/get_gabs_logo.png';  // 🟦 GetGabs ka PNG Logo path
  }

  static String get getgabsLogoPng {
    return currentFlavor == 'messagedly'
        ? 'assets/images/messagedly_logo.png' // 🟧 Messagedly ka dusra PNG Logo path (Splash ke liye jo use ho raha tha)
        : 'assets/images/gglogo.png';          // 🟦 GetGabs ka dusra PNG Logo path
  }

  //-------------------------- Common SVG Images (Jo dono apps mein same hain) ---------------------------------
  static const String startScreenImageSvg = 'assets/images/startpage.svg';
  static const String filterIconSvg = 'assets/images/filter.svg';
  static const String chatSvg = 'assets/images/chat.svg';
  static const String notificationSvg = 'assets/images/notification.svg';
  static const String moreSvg = 'assets/images/more.svg';
  static const String moreProfileIcon = 'assets/images/profile_icon.svg';
  static const String menuIcon = 'assets/images/menu_icon.svg';
  static const String messageChatIcon = 'assets/images/message_chat_icon.svg';
  static const String searchIcon = 'assets/images/search_icon.svg';
  static const String metaIcon = 'assets/images/meta_icon.svg';
  static const String logoutIcon = 'assets/images/logout_icon.svg';
  static const String circleUserRoundIcon = 'assets/images/circle_user_round_icon.svg';

  //-------------------------- Common PNG Images (Jo dono apps mein same hain) ---------------------------------
  static const String ss = 'assets/images/a.png';
  static const String filterIconPng = 'assets/images/filter.png';
  static const String chatPng = 'assets/images/chat.png';
  static const String notificationPng = 'assets/images/notification.png';
  static const String morePng = 'assets/images/more.png';
  static const String calendarPng = 'assets/images/calendar.png';
  static const String profileImage = 'assets/images/profile_image.png';
  static const String signOutLogo = 'assets/images/signout.png';
  static const String moreProfileIconPng = 'assets/images/profile_icon.png';
  static const String searchIconPng = 'assets/images/search.png';
  static const String reverseArrowPng = 'assets/images/arrows.png';
}