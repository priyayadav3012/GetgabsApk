import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';

import '../../../ui/res/widgets/customDailogBox/customdailog.dart';

class ProfileController extends GetxController {
  // User profile details
  var userName = ' '.obs;
  var email = ' '.obs;
  var phoneNumber = ' '.obs;
  var role = ' '.obs;
  GetStorageUserData userData = GetStorageUserData();

  @override
  void onInit() {
    var data = userData.getUserDataInOneShot();
    data.then((value) {
      print(value);
      userName.value = value!['name'];
      email.value = value['email'];
      phoneNumber.value = value['phone'].toString();
      if (value['role'] == 'user') {
        role.value = 'Admin';
      } else if (value['role'] == 'sub-user') {
        role.value = 'Executive';
      } else {
        role.value = 'Manager';
      }
      // print(value!['name']);
      // print(value['email']);
      // print(value['phone']);
      // print(value['role']);
    });
    
    super.onInit();
  }

  // Function to handle password change navigation
  void navigateToChangePassword() {
    Get.toNamed('/change-password'); // Adjust route name as per your setup
  }

  // Function to show delete account confirmation dialog
  void confirmDeleteAccount() {
    Get.generalDialog(
      barrierDismissible: false,
      barrierLabel: "Delete Account",
      pageBuilder: (context, __, ___) {
        return CustomDialog(
          title: "Are you sure you want to delete your account?",
          yesButtonText: "Yes",
          noButtonText: "No",
          onYesPressed: () {
            Get.back(); // Close dialog
          },
          onNoPressed: () {
            Get.back(); // Close dialog
          },
        );
      },
      transitionDuration: const Duration(milliseconds: 800),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: const Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );
  }
}
