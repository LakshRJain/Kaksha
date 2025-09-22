import 'package:flutter/material.dart';
import 'package:classcare/widgets/Colors.dart';
import 'calendar_event.dart';

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool isTeacher;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  EventCard({
    required this.event,
    required this.isTeacher,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: event.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: event.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (event.isRecurring) ...[
                      SizedBox(width: 8),
                      Icon(Icons.repeat, color: event.color, size: 16),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  event.startTime.toString(), // format as needed
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (event.description.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isTeacher)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit, color: Colors.blue, size: 16),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete, color: Colors.redAccent, size: 16),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
