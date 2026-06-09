import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // 🕵️‍♂️ Yeh line automatically check karegi ki kaunsa flavor run ho raha hai
  static const String currentFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

  // ============== 🔑 COMMON COLORS (Jo dono apps mein bilkul same hain) ==============
  static const Color blackColor = Color(0xff000000);
  static const Color whiteColor = Color(0xffffffff);
  static const Color primaryBoarderColor = Color(0xffDEDEDE);
  static const Color black54 = Colors.black54;
  static const Color greyColor = Colors.grey;
  static const Color greyColors = Color(0xff23291F);
  static const Color recivedMessageBg = Color(0xffF5F5F5);
  static const Color messageTime = Color(0xff4D524A);
  static const Color lightGrey = Color(0xffD9D9D9);
  static const Color blackcolor2 = Color(0xff22281F);
  static const Color boarderColorRolling = Color(0xffFFF177);
  static const Color profilesubtitle = Color(0x00787878);
  static const Color messageDate = Color(0xff23291F);
  static const Color attachmentsIcons = Color(0xffDDDDDD);
  static const Color moreIconColor = Color(0xff3E403F);
  static const Color moreTextColor = Color(0xff22281E);
  static const Color extraColor = Color(0xffF5FAF4);
  static const Color customOrange = Color(0xFFFF3D00);
  static const Color customRed = Color(0xFFEC1111);
  static const Color daysColor = Color(0xff6BDE59);
  static const Color linkColors = Color(0xff1BA4CF);

  // ============== 🎨 DYNAMIC COLORS (Jo flavor ke hisab se badlenge) ==============

  static Color get appThemeColor {
    return currentFlavor == 'messagedly' 
        ? const Color(0xff4242D4) // Messagedly Blue
        : const Color(0xff034737); // GetGabs Green
  }

  static Color get authButtonColor {
    return currentFlavor == 'messagedly' 
        ? const Color(0xff4242D4) // Messagedly Blue (Aapke code mein typo tha 0xff04242D4, use fix kiya hai)
        : const Color(0xff034737); // GetGabs Green
  }

  static Color get boarderColor {
    return currentFlavor == 'messagedly' 
        ? const Color.fromARGB(255, 156, 178, 250) 
        : const Color(0xff77FFAA);
  }

  static Color get unreadMessagesColor {
    return currentFlavor == 'messagedly' 
        ? const Color(0xff4242D4)
        : const Color(0xff5ED88C);
  }

  static Color get messagesColor {
    return currentFlavor == 'messagedly' 
        ? const Color.fromARGB(255, 230, 237, 255) 
        : const Color(0xffDCFCD7);
  }

  // ============== 📝 STYLES ==============
  static TextStyle tabViewHeadingStyle = const TextStyle(
    fontFamily: 'Philosopher',
    color: AppTheme.blackColor,
    fontSize: 24,
  );
}