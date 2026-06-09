import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../domain/controllers/more/ProfileController.dart';
import 'package:getgabs/ui/themes/themes.dart';

class ProfileScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();
  // final ProfileController profileController = Get.put(ProfileController());

   ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: AppTheme.extraColor,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 4.0,
        shadowColor: Colors.black.withOpacity(0.5),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
              child: Text(
                "Profile Information",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.appThemeColor,
                  fontSize: screenWidth * 0.03,
                ),
              ),
            ),
            Obx(() => ProfileInfoTile(
              label: 'User Name',
              value: profileController.userName.value,
              screenWidth: screenWidth,
            )),
            Obx(() => ProfileInfoTile(
              label: 'Email',
              value: profileController.email.value,
              screenWidth: screenWidth,
            )),
            Obx(() => ProfileInfoTile(
              label: 'Phone Number',
              value: profileController.phoneNumber.value,
              screenWidth: screenWidth,
            )),
            Obx(() => ProfileInfoTile(
              label: 'Role In Business',
              value: profileController.role.value,
              screenWidth: screenWidth,
            )),
            SizedBox(height: screenHeight * 0.030),
            // Padding(
            //   padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.01),
            //   child: Text(
            //     "Account Setting",
            //     style: TextStyle(
            //       fontWeight: FontWeight.w500,
            //       color: AppTheme.appThemeColor,
            //       fontSize: 14,
            //     ),
            //   ),
            // ),
            // Container(
            //   color: Colors.white,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: [
            //       AccountButton(
            //         iconPath: "assets/images/change-password.png",
            //         label: 'Change Password',
            //         color: Colors.blue,
            //         onTap: profileController.navigateToChangePassword,
            //         screenWidth: screenWidth,
            //       ),
            //       AccountButton(
            //         iconPath: "assets/images/delete-account.png",
            //         label: 'Delete Account',
            //         color: Colors.red,
            //         onTap: profileController.confirmDeleteAccount,
            //         screenWidth: screenWidth,
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final double screenWidth;

  const ProfileInfoTile({super.key, required this.label, required this.value, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.10, vertical: 18),
      color: Colors.white,
      width: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountButton extends StatelessWidget {
  final String iconPath;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double screenWidth;

  const AccountButton({super.key, 
    required this.iconPath,
    required this.label,
    required this.color,
    required this.onTap,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: screenWidth * 0.05),
        child: Row(
          children: [
            Image.asset(iconPath),
            SizedBox(width: screenWidth * 0.02),
            Text(
              label,
              style: TextStyle(color: color, fontSize: screenWidth * 0.04),
            ),
          ],
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/routes/app_route.dart';
// import 'package:getgabs/ui/themes/themes.dart';

// import '../../../../res/widgets/customDailogBox/customdailog.dart';

// class ProfileScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final mediaQuery = MediaQuery.of(context);
//     final screenWidth = mediaQuery.size.width;
//     final screenHeight = mediaQuery.size.height;

//     return Scaffold(
//       backgroundColor: AppTheme.extraColor,
//       appBar:AppBar(
//         title: const Text(
//           'My Profile',
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 4.0,
//         shadowColor: Colors.black.withOpacity(0.5),
       
//       ),
      
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
//               child: Text(
//                 "Profile Information",
//                 style: TextStyle(
//                   fontWeight: FontWeight.w500,
//                   color: AppTheme.appThemeColor,
//                   fontSize: screenWidth * 0.03, 
//                 ),
//               ),
//             ),
//             ProfileInfoTile(
//               label: 'User Name',
//               value: 'Aadrik Rastogi',
//               screenWidth: screenWidth,
//             ),
//             ProfileInfoTile(
//               label: 'Email',
//               value: 'Aadrik@getgabs.com',
//               screenWidth: screenWidth,
//             ),
//             ProfileInfoTile(
//               label: 'Phone Number',
//               value: '+91973478xxxx',
//               screenWidth: screenWidth,
//             ),
//             ProfileInfoTile(
//               label: 'Role In Business',
//               value: 'Sales Executive',
//               screenWidth: screenWidth,
//             ),
//             SizedBox(height: screenHeight * 0.030), 
//             Padding(
//               padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.01),
//               child: Text(
//                 "Account Setting",
//                 style: TextStyle(
//                   fontWeight: FontWeight.w500,
//                   color: AppTheme.appThemeColor,
//                   fontSize: 14, 
//                 ),
//               ),
//             ),
//             Container(
//               color: Colors.white,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   AccountButton(
//                     iconPath: "assets/images/change-password.png",
//                     label: 'Change Password',
//                     color: Colors.blue,
//                     onTap: () {
//                     // Get.toNamed(AppRoute.changePasswordScreen);
//                     },
//                     screenWidth: screenWidth,
//                   ),
//                   AccountButton(
//                     iconPath: "assets/images/delete-account.png",
//                     label: 'Delete Account',
//                     color: Colors.red,
//                     onTap: () {
//               Get.generalDialog(
//                 barrierDismissible: false,
//                 barrierLabel: "Rate Us",
//                 pageBuilder: (context, __, ___) {
//                   return CustomDialog(
//                     title: "Are you sure you want to delete your account?",
//                     yesButtonText: "Yes",
//                     noButtonText: "No",
//                     onYesPressed: () {
//                       Get.back();
                      
//                     },
//                     onNoPressed: () {
//                       Get.back();
//                     },
//                   );
//                 },
//                 transitionDuration: Duration(milliseconds: 800),
//                 transitionBuilder: (context, anim1, anim2, child) {
//                   return SlideTransition(
//                     position: Tween<Offset>(
//                       begin: Offset(0, -1), 
//                       end: Offset(0, 0), 
//                     ).animate(anim1),
//                     child: child,
//                   );
//                 },
//               );
//             },
//                     screenWidth: screenWidth,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class ProfileInfoTile extends StatelessWidget {
//   final String label;
//   final String value;
//   final double screenWidth;

//   const ProfileInfoTile({required this.label, required this.value, required this.screenWidth});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.10, vertical: 18),
//       color: Colors.white,
//       width: screenWidth,
//       // height: 90,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.w400,
//               color: Colors.grey[600],
//               fontSize: 14, 
//             ),
//           ),
//           SizedBox(height: 4),
//           Text(
//             value,
//             style: TextStyle(
//               fontWeight: FontWeight.w400,
//               fontSize: 16, 
//               color: Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class AccountButton extends StatelessWidget {
//   final String iconPath;
//   final String label;
//   final Color color;
//   final VoidCallback onTap;
//   final double screenWidth;

//   const AccountButton({
//     required this.iconPath,
//     required this.label,
//     required this.color,
//     required this.onTap,
//     required this.screenWidth,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(vertical: 20, horizontal: screenWidth * 0.05),
//         child: Row(
//           children: [
//             Image.asset(
//               iconPath,
              
//             ),
//             SizedBox(width: screenWidth * 0.02),
//             Text(
//               label,
//               style: TextStyle(color: color, fontSize: screenWidth * 0.04), 
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
