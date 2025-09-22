import 'package:classcare/screens/student/hometStudent.dart';
import 'package:flutter/material.dart';
import 'event_type.dart';
import 'package:classcare/widgets/Colors.dart';

class Legend extends StatelessWidget {
  final List<EventType> eventTypes;
  Legend({required this.eventTypes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: eventTypes
            .map((eventType) => _buildLegendItem(
                eventType.name, eventType.color, eventType.icon))
            .toList(),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Icon(icon, color: color, size: 14),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
