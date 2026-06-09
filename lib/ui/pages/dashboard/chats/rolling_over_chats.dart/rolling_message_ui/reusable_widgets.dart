import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/themes/themes.dart';

class ReusableWidgets {
  static Widget authButton(
      {required name, required onPressed, requied, required mediaQuery,required Padding}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.authButtonColor,
        padding: EdgeInsets.symmetric(
            horizontal: mediaQuery.width * 0.34,
            vertical: mediaQuery.height * 0.022),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(38.0),
        ),
      ),
      child:  Text(
       name ,
        style: const TextStyle(color: AppTheme.whiteColor),
      ),
    );
  }

  //   static svgAssets(
  //     {required String img, double height = 100, double width = 100}) {
  //   return SvgPicture.asset(
  //     img,
  //     height: height,
  //     width: width,
  //   );
  // }

  // static reUseableButton({required mediaQuery, required onPressed,required buttonName}){
  //   return  InkWell(
  //                       onTap:onPressed,
  //                       child: Container(
  //                         width: mediaQuery.width * 0.5,
  //                         height: mediaQuery.height * .063,
  //                         alignment: Alignment.center,
  //                         decoration: BoxDecoration(
  //                           color: AppTheme.appThemeColor,
  //                           borderRadius: BorderRadius.circular(10),
  //                         ),
  //                         child: Padding(
  //                           padding: const EdgeInsets.all(4.0),
  //                           child:  Text(
  //                             buttonName,
  //                             style: const TextStyle(
  //                                 color: Colors.white,
  //                                 fontWeight: FontWeight.bold,
  //                                 fontSize: 20),
  //                           ),
  //                         ),
  //                       ));
  // }

    static snackBar(String title, String message,{Color titleColor=AppTheme.whiteColor,Color messageColor=AppTheme.whiteColor}) {
    Get.snackbar(
      title,
      message,
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
      duration: const Duration(seconds: 3),
      barBlur: 30,
      colorText: Colors.white,
      backgroundColor: Colors.redAccent,
      messageText: Text(
        message,
        style: TextStyle(fontSize: 16,color: titleColor,),
      ),
      titleText: Text(
        title,
        style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: messageColor,),
      ),
    );
  }
}
