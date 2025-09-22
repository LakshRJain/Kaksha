import 'package:flutter/material.dart';
import 'calendar_state.dart';

class CalendarScreen extends StatefulWidget {
  final String classId;
  final String className;
  final bool isTeacher;

  const CalendarScreen({
    Key? key,
    required this.classId,
    required this.className,
    required this.isTeacher,
  }) : super(key: key);

  @override
  CalendarScreenState createState() => CalendarScreenState();
}
