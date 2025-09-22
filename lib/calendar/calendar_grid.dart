// Removed unused import of hometStudent
import 'package:classcare/widgets/Colors.dart';
import 'package:flutter/material.dart';
import 'calendar_event.dart';
import 'package:intl/intl.dart';

class CalendarGrid extends StatelessWidget {
  final DateTime currentMonth;
  final List<CalendarEvent> events;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onNavigateMonth;
  final DateTime selectedDate;
  final List<CalendarEvent> Function(DateTime)? getEventsForDate;

  CalendarGrid({
    required this.currentMonth,
    required this.events,
    required this.onDaySelected,
    required this.onNavigateMonth,
    required this.selectedDate,
    this.getEventsForDate,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstDayWeekday; i++) {
      dayWidgets.add(Container());
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final eventsForDay = getEventsForDate != null
          ? getEventsForDate!(date)
          : events
              .where((event) =>
                  event.startTime.year == date.year &&
                  event.startTime.month == date.month &&
                  event.startTime.day == date.day)
              .toList();
      final isToday = date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      final isSelected = date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () => onDaySelected(date),
          child: Container(
            margin: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : isToday
                      ? Colors.blue.withOpacity(0.2)
                      : const Color.fromARGB(0, 215, 23, 23),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : isToday
                      ? Border.all(color: Colors.blue, width: 1)
                      : null,
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  day.toString(),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: AppColors.primaryText),
                ),
                if (eventsForDay.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    height: 4,
                    width: 4,
                    decoration: BoxDecoration(
                      color: eventsForDay.first.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Month Navigation
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => onNavigateMonth(DateTime(
                  currentMonth.year,
                  currentMonth.month - 1,
                )),
                icon: Icon(Icons.chevron_left, color: Colors.blue),
              ),
              Text(
                DateFormat('MMMM yyyy').format(currentMonth),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText),
              ),
              IconButton(
                onPressed: () => onNavigateMonth(DateTime(
                  currentMonth.year,
                  currentMonth.month + 1,
                )),
                icon: Icon(Icons.chevron_right, color: Colors.blue),
              ),
            ],
          ),
        ),
        // Day grid
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [
            Center(
                child: Text('Mon',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            Center(
                child: Text('Tue',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            Center(
                child: Text('Wed',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            Center(
                child: Text('Thu',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            Center(
                child: Text('Fri',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            Center(
                child: Text('Sat',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            Center(
                child: Text('Sun',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.primaryText))),
            ...dayWidgets,
          ],
        )
      ],
    );
  }
}
