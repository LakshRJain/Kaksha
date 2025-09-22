import 'package:flutter/material.dart';
class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;
  final String type;
  final String description;
  final bool isRecurring;
  final String recurrencePattern;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.type,
    required this.description,
    required this.isRecurring,
    required this.recurrencePattern,
  });
}