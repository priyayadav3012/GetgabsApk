  import 'package:flutter/material.dart';

class PredefiendLogicesUtils{
  static bool isSameDate(DateTime givenDate) {
    DateTime now = DateTime.now();

    // Compare the year, month, and day of the given date and today's date
    if (givenDate.year == now.year &&
        givenDate.month == now.month &&
        givenDate.day == now.day) {
      return true; // The dates are the same
    } else {
      return false; // The dates are different
    }
  }

  static void fieldFocusChange(
      BuildContext context, FocusNode current, FocusNode nextFocus) {
    current.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }
}
  
  