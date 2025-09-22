import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:classcare/widgets/Colors.dart';
import 'calendar_event.dart';
import 'event_type.dart';

/// Dialog for adding a new event
Future<void> showAddEventDialog({
  required BuildContext context,
  required String classId,
  required Function() onUpdate,
  required List<EventType> eventTypes,
  required DateTime initialDate,
  CalendarEvent? existingEvent,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController =
      TextEditingController(text: existingEvent?.title ?? '');
  final TextEditingController _descController =
      TextEditingController(text: existingEvent?.description ?? '');

  EventType? _selectedType = existingEvent != null
      ? eventTypes.firstWhere(
          (t) => t.name == existingEvent.type,
          orElse: () => EventType('Other', Icons.event_note, Colors.grey),
        )
      : null;
  TimeOfDay? _startTime = existingEvent != null
      ? TimeOfDay.fromDateTime(existingEvent.startTime)
      : null;
  TimeOfDay? _endTime = existingEvent != null
      ? TimeOfDay.fromDateTime(existingEvent.endTime)
      : null;
  bool _isRecurring = existingEvent?.isRecurring ?? false;
  String _recurrencePattern =
      existingEvent?.recurrencePattern.isNotEmpty == true
          ? existingEvent!.recurrencePattern
          : "Daily";
  DateTime _selectedDate = DateTime(
    (existingEvent?.startTime ?? initialDate).year,
    (existingEvent?.startTime ?? initialDate).month,
    (existingEvent?.startTime ?? initialDate).day,
  );

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        title: Text(existingEvent == null ? "Add Event" : "Edit Event",
            style: const TextStyle(color: AppColors.primaryText)),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    labelText: "Event Title",
                    labelStyle: const TextStyle(color: AppColors.secondaryText),
                    filled: true,
                    fillColor: AppColors.surfaceColor,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.tertiaryText.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.tertiaryText.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: AppColors.accentBlue, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? "Please enter a title"
                      : null,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.primaryText),
                  decoration: InputDecoration(
                    labelText: "Description",
                    labelStyle: const TextStyle(color: AppColors.secondaryText),
                    filled: true,
                    fillColor: AppColors.surfaceColor,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.tertiaryText.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.tertiaryText.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: AppColors.accentBlue, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Date Picker
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Date: ${_selectedDate.toLocal().toString().split(' ')[0]}",
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.accentBlue,
                                  surface: AppColors.cardColor,
                                  onSurface: AppColors.primaryText,
                                ),
                                dialogBackgroundColor: AppColors.cardColor,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: const Text(
                        "Pick Date",
                        style: TextStyle(color: AppColors.accentBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Event Type Dropdown
                DropdownButtonFormField<EventType>(
                  value: _selectedType,
                  hint: const Text("Select Event Type",
                      style: TextStyle(color: AppColors.secondaryText)),
                  items: eventTypes
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name),
                          ))
                      .toList(),
                  dropdownColor: AppColors.cardColor,
                  style: const TextStyle(color: AppColors.primaryText),
                  onChanged: (val) => setState(() => _selectedType = val),
                  validator: (val) =>
                      val == null ? "Please select an event type" : null,
                ),
                const SizedBox(height: 12),

                // Start Time
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _startTime == null
                            ? "No start time"
                            : "Start: ${_startTime!.format(context)}",
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _startTime = picked);
                        }
                      },
                      child: const Text("Pick Start",
                          style: TextStyle(color: AppColors.accentBlue)),
                    ),
                  ],
                ),

                // End Time
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _endTime == null
                            ? "No end time"
                            : "End: ${_endTime!.format(context)}",
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _endTime = picked);
                        }
                      },
                      child: const Text("Pick End",
                          style: TextStyle(color: AppColors.accentBlue)),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SwitchListTile(
                  title: const Text("Recurring Event",
                      style: TextStyle(color: AppColors.primaryText)),
                  value: _isRecurring,
                  onChanged: (val) => setState(() => _isRecurring = val),
                  activeColor: AppColors.accentBlue,
                ),

                if (_isRecurring)
                  DropdownButtonFormField<String>(
                    value: _recurrencePattern,
                    items: ["Daily", "Weekly", "Monthly", "Yearly"]
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    dropdownColor: AppColors.cardColor,
                    style: const TextStyle(color: AppColors.primaryText),
                    onChanged: (val) {
                      if (val != null) setState(() => _recurrencePattern = val);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (existingEvent != null)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    backgroundColor: AppColors.cardColor,
                    title: const Text('Delete Event',
                        style: TextStyle(color: AppColors.primaryText)),
                    content: const Text(
                      'Are you sure you want to delete this event?',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .collection('schedules')
                      .doc(existingEvent.id)
                      .delete();
                  onUpdate();
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: BorderSide(color: AppColors.accentBlue),
            ),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final startDateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _startTime?.hour ?? 0,
                  _startTime?.minute ?? 0,
                );

                final endDateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _endTime?.hour ?? 0,
                  _endTime?.minute ?? 0,
                );

                if (existingEvent == null) {
                  final event = CalendarEvent(
                    id: UniqueKey().toString(),
                    title: _titleController.text,
                    description: _descController.text,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    color: _selectedType?.color ?? AppColors.accentBlue,
                    type: _selectedType?.name ?? "General",
                    isRecurring: _isRecurring,
                    recurrencePattern: _recurrencePattern,
                  );

                  await FirebaseFirestore.instance
                      .collection("classes")
                      .doc(classId)
                      .collection("schedules")
                      .add({
                    "title": event.title,
                    "description": event.description,
                    "startTime": event.startTime,
                    "endTime": event.endTime,
                    "eventType": event.type,
                    "isRecurring": event.isRecurring,
                    "recurrencePattern": event.recurrencePattern,
                    "createdAt": FieldValue.serverTimestamp(),
                    "createdBy": user?.uid ?? "unknown",
                  });
                } else {
                  await FirebaseFirestore.instance
                      .collection("classes")
                      .doc(classId)
                      .collection("schedules")
                      .doc(existingEvent.id)
                      .update({
                    "title": _titleController.text,
                    "description": _descController.text,
                    "startTime": startDateTime,
                    "endTime": endDateTime,
                    "eventType": _selectedType?.name ?? existingEvent.type,
                    "isRecurring": _isRecurring,
                    "recurrencePattern": _recurrencePattern,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "updatedBy": user?.uid ?? "unknown",
                  });
                }

                onUpdate(); // refresh parent
                Navigator.of(ctx).pop();
              }
            },
            child: const Text(
              "Save",
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dialog to show events for a given date
Future<void> showEventsForDateDialog({
  required BuildContext context,
  required DateTime date,
  required List<CalendarEvent> events,
  required bool isTeacher,
  required String classId,
  required Function() onUpdate,
  required List<EventType> eventTypes,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Events on ${date.toLocal().toString().split(' ')[0]}"),
      content: events.isEmpty
          ? const Text("No events for this day")
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: events
                    .map(
                      (event) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: event.color,
                          ),
                          title: Text(event.title),
                          subtitle: Text(
                              "Time: ${TimeOfDay.fromDateTime(event.startTime).format(context)}"),
                          trailing: isTeacher
                              ? IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    // You can call another dialog like showEditEventDialog
                                    await showAddEventDialog(
                                      context: context,
                                      classId: classId,
                                      onUpdate: onUpdate,
                                      eventTypes: eventTypes,
                                      initialDate: date,
                                      existingEvent: event,
                                    );
                                  },
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}
