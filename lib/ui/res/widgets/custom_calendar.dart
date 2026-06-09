import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../domain/controllers/calendar/calendar_controller.dart';

class CustomCalendar extends StatelessWidget {
  const CustomCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final CalendarController calendarController = Get.put(CalendarController());

    return Container(
      height:  Get.height * 0.6,
      margin: EdgeInsets.all(mediaQuery.size.width * 0.02), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04), 
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: mediaQuery.size.width * 0.05, 
            spreadRadius: 2,
            offset: Offset(0, mediaQuery.size.height * 0.01),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(mediaQuery.size.width * 0.04), 
        child: Column(
          children: [
            Obx(() => TableCalendar(
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: calendarController.focusedDay.value,
              selectedDayPredicate: (day) {
                return isSameDay(calendarController.selectedDay.value, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                calendarController.onDaySelected(selectedDay, focusedDay);
              },
              calendarFormat: CalendarFormat.month,

              
              daysOfWeekHeight: mediaQuery.size.height * 0.05,  

              daysOfWeekStyle: DaysOfWeekStyle(
                weekendStyle: TextStyle(
                  color:AppTheme.daysColor,
                  fontSize: mediaQuery.size.width * 0.03, 
                  
                ),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color:AppTheme.messagesColor,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.black
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color:AppTheme.messagesColor,),
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.black
                ),
                weekendTextStyle: TextStyle(
                  
                  fontSize: mediaQuery.size.width * 0.03, 
                ),
                defaultTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: mediaQuery.size.width * 0.03, 
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                  size: mediaQuery.size.width * 0.05, 
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Colors.black,
                  size: mediaQuery.size.width * 0.05, 
                ),
                titleTextStyle: TextStyle(
                  fontSize: mediaQuery.size.width * 0.04, 
                  fontWeight: FontWeight.w600,
                ),
              ),
            )),
          ],
        ),
      ),
     
    );
    
  }
}
