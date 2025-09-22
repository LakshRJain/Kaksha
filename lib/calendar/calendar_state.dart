import 'calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:classcare/widgets/Colors.dart';

import 'calendar_event.dart';
import 'event_type.dart';
import 'legend.dart';
import 'calendar_grid.dart';
import 'event_dialogs.dart';
import 'event_card.dart';

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _isLoading = true;

  // Event types
  final List<EventType> _eventTypes = [
    EventType('Class', Icons.school, AppColors.accentBlue),
    EventType('Meeting', Icons.people, AppColors.accentGreen),
    EventType('Exam', Icons.quiz, AppColors.accentRed),
    EventType('Assignment Due', Icons.assignment, AppColors.accentYellow),
    EventType('Holiday', Icons.event, AppColors.accentPurple),
    EventType('Other', Icons.event_note, Colors.grey),
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot scheduleSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('schedules')
          .get();

      QuerySnapshot assignmentSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('assignments')
          .get();

      List<CalendarEvent> events = [];

      // Add schedules
      for (var doc in scheduleSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        events.add(CalendarEvent(
          id: doc.id,
          title: data['title'] ?? 'Class Schedule',
          startTime: (data['startTime'] as Timestamp).toDate(),
          endTime: (data['endTime'] as Timestamp).toDate(),
          color: _getEventTypeColor(data['eventType'] ?? 'Class'),
          type: data['eventType'] ?? 'Class',
          description: data['description'] ?? '',
          isRecurring: data['isRecurring'] ?? false,
          recurrencePattern: data['recurrencePattern'] ?? '',
        ));
      }

      // Add assignment deadlines
      for (var doc in assignmentSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime dueDate = DateTime.parse(data['dueDate']);
        events.add(CalendarEvent(
          id: doc.id,
          title: '${data['title']} - Due',
          startTime: dueDate,
          endTime: dueDate.add(Duration(hours: 1)),
          color: AppColors.accentRed,
          type: 'Assignment Due',
          description: data['description'] ?? '',
          isRecurring: false,
          recurrencePattern: '',
        ));
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'Class':
        return AppColors.accentBlue;
      case 'Meeting':
        return AppColors.accentGreen;
      case 'Exam':
        return AppColors.accentRed;
      case 'Assignment Due':
        return AppColors.accentYellow;
      case 'Holiday':
        return AppColors.accentPurple;
      default:
        return Colors.grey;
    }
  }

  List<CalendarEvent> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      if (event.isRecurring && event.recurrencePattern.isNotEmpty) {
        return _isRecurringEventOnDate(event, date);
      }
      return event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day;
    }).toList();
  }

  bool _isRecurringEventOnDate(CalendarEvent event, DateTime date) {
    if (!event.isRecurring) return false;
    switch (event.recurrencePattern) {
      case 'Daily':
        return date.isAfter(event.startTime.subtract(Duration(days: 1)));
      case 'Weekly':
        return date.weekday == event.startTime.weekday &&
            date.isAfter(event.startTime.subtract(Duration(days: 1)));
      case 'Monthly':
        return date.day == event.startTime.day &&
            date.isAfter(event.startTime.subtract(Duration(days: 1)));
      case 'Yearly':
        return date.month == event.startTime.month &&
            date.day == event.startTime.day &&
            date.isAfter(event.startTime.subtract(Duration(days: 1)));
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(
          color: AppColors.primaryText,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: const Color.fromARGB(0, 29, 126, 110),
        elevation: 0,
        title: Text(
          '${widget.className} Calendar',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (widget.isTeacher)
            IconButton(
              icon: Icon(Icons.add, color: AppColors.accentBlue),
              onPressed: () => showAddEventDialog(
                context: context,
                classId: widget.classId,
                onUpdate: _loadEvents,
                eventTypes: _eventTypes,
                initialDate: _selectedDate,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue))
          : Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Legend(eventTypes: _eventTypes),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CalendarGrid(
                        currentMonth: _currentMonth,
                        events: _events,
                        onDaySelected: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        onNavigateMonth: (newMonth) {
                          setState(() {
                            _currentMonth = newMonth;
                          });
                        },
                        selectedDate: _selectedDate,
                        getEventsForDate: _getEventsForDate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Selected day events list
                    Container(
                      margin: EdgeInsets.fromLTRB(22, 0, 22, 22),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEEE, d MMM yyyy')
                                    .format(_selectedDate),
                                style: TextStyle(
                                  color: AppColors.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_getEventsForDate(_selectedDate).length} events',
                                  style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_getEventsForDate(_selectedDate).isEmpty)
                            Text(
                              'No events',
                              style: TextStyle(color: AppColors.secondaryText),
                            )
                          else
                            ..._getEventsForDate(_selectedDate)
                                .map(
                                  (e) => EventCard(
                                    event: e,
                                    isTeacher: widget.isTeacher,
                                    onEdit: () async {
                                      await showAddEventDialog(
                                        context: context,
                                        classId: widget.classId,
                                        onUpdate: _loadEvents,
                                        eventTypes: _eventTypes,
                                        initialDate: e.startTime,
                                        existingEvent: e,
                                      );
                                    },
                                    onDelete: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppColors.cardColor,
                                          title: const Text('Delete Event',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.primaryText)),
                                          content: const Text(
                                            'Are you sure you want to delete this event?',
                                            style: TextStyle(
                                                color: AppColors.secondaryText),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.redAccent)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await FirebaseFirestore.instance
                                            .collection('classes')
                                            .doc(widget.classId)
                                            .collection('schedules')
                                            .doc(e.id)
                                            .delete();
                                        await _loadEvents();
                                      }
                                    },
                                  ),
                                )
                                .toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
    );
  }
}
