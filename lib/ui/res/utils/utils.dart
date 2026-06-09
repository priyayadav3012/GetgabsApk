import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../themes/themes.dart';

class Utils {
  static void fieldFocusChange(
      BuildContext context, FocusNode current, FocusNode nextFocus) {
    current.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  static toastMessage(String message) {
    Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppTheme.blackColor,
        gravity: ToastGravity.TOP);
  }

  static snackBar(String title, String message) {
    Get.snackbar(
      title,
      message,
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
      duration: const Duration(seconds: 3),
      barBlur: 30,
      colorText: Colors.black,
      backgroundColor: AppTheme.lightGrey.withOpacity(0.5),
      messageText: Text(
        message,
        style:const TextStyle(fontSize: 16),
      ),
      titleText: Text(
        title,
        style:const TextStyle(fontSize: 18,fontWeight: FontWeight.bold),
      ),
    );
  }

  static svgAssets(
      {required String img, double height = 100, double width = 100}) {
    return SvgPicture.asset(
      img,
      height: height,
      width: width,
    );
  }



}
