import 'package:get/get.dart';

class CalendarController extends GetxController {
  // Reactive properties
  var selectedDay = DateTime.now().obs;
  var focusedDay = DateTime.now().obs;

  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
  }
}
