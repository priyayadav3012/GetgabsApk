// import 'package:flutter/services.dart';
// import 'package:get/get.dart';

// class Validator {
//   static RegExp alphaNumberRic =
//       RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');

//   static List<TextInputFormatter>? nameFormatterWithSpecialChar = [
//     FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9@#\$%^&*()_-]')),
//   ];

//   static List<TextInputFormatter>? mobileNumberFormatter = [
//     FilteringTextInputFormatter.allow(RegExp('[0-9-_+]'))
//   ];

//   static String? passwordValid(String? v) {
//     if (v!.isEmpty) {
//       return R.validation.ksEmptyPassword;
//     } else {
//       return null;
//     }
//   }

//   static String? validateEmail(String? v) {
//     if (v!.toString().trim().isEmpty) {
//       return R.validation.ksEmailError;
//     } else if (!GetUtils.isEmail(v.trim())) {
//       return R.validation.ksValidEmail;
//     } else {
//       return null;
//     }
//   }

//   static String? validateFirstName(String? v) {
//     if (v!.toString().trim().isEmpty) {
//       return R.validation.ksFirstNameError;
//     } else if (v.length > 25) {
//       return R.validation.ksValidFirstNameError;
//     } else {
//       return null;
//     }
//   }

//   static String? validLastName(String? v) {
//     if (v!.toString().trim().isEmpty) {
//       return R.validation.ksLastNameError;
//     } else if (v.length > 25) {
//       return R.validation.ksValidLastNameError;
//     } else {
//       return null;
//     }
//   }

//   static String? validateUserName(String? v) {
//     if (v!.toString().trim().isEmpty) {
//       return R.validation.ksUserNameError;
//     } else {
//       return null;
//     }
//   }

//   static String? validNumber(String? v) {
//     if (v!.isEmpty) {
//       return R.validation.ksEmptyMobile;
//     } else if (v.length < 7) {
//       return R.validation.ksValidMobile;
//     } else if (v.length > 15) {
//       return R.validation.ksValidMobile;
//     } else {
//       return null;
//     }
//   }

//   static String? validateNewPassword(String? v) {
//     if (v!.isEmpty) {
//       return R.validation.ksErrorNewPassword;
//     } else if (!alphaNumberRic.hasMatch(v)) {
//       return R.validation.ksValidPassword;
//     } else {
//       return null;
//     }
//   }

//   static String? validOtp(String? v) {
//     if (v!.length < 6) {
//       return R.validation.ksEnter6DigitOpt;
//     } else {
//       return null;
//     }
//   }


//   static String? validHomeAddress(String? v) {
//     if (v!.toString().trim().isEmpty) {
//       return R.validation.ksEmptyHomeAddress;
//     } else {
//       return null;
//     }
//   }

//   static String? validOfficeAddress(String? v) {
//     if (v!.toString().trim().isEmpty) {
//       return R.validation.ksEmptyOfficeAddress;
//     } else {
//       return null;
//     }
//   }
// }
