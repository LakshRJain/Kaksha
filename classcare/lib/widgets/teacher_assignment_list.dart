import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'assignment_detail_screen.dart';

class AssignmentList extends StatelessWidget {
  final String classId;
  final bool isCurrent;

  const AssignmentList({Key? key, required this.classId, required this.isCurrent})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .collection('assignments')
            .orderBy('dueDate', descending: !isCurrent)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var assignments = snapshot.data!.docs.where((doc) {
            DateTime dueDate = DateTime.parse(doc['dueDate']);
            return isCurrent
                ? dueDate.isAfter(DateTime.now())
                : dueDate.isBefore(DateTime.now());
          }).toList();

          if (assignments.isEmpty) {
            return Center(
                child: Text(isCurrent
                    ? "No current assignments."
                    : "No past assignments."));
          }

          return ListView.builder(
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              var assignment = assignments[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(assignment['title']),
                  subtitle: Text(
                    "Due Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(assignment['dueDate']))}",
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    // Navigate to AssignmentDetailScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignmentDetailScreen(
                          classId: classId,
                          assignmentId: assignment['assignmentId'],

                          title: assignment['title'],
                          description: assignment['description'],
                          dueDate: assignment['dueDate'],
                          fileUrl: assignment['fileUrl'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
