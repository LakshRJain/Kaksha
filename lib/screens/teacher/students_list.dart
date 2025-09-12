import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classcare/widgets/Colors.dart';

class StudentsList extends StatelessWidget {
  final String classId;

  const StudentsList({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('classes').doc(classId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.accentBlue,
              strokeWidth: 3,
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyState("No class data found.");
        }

        // Check if 'students' field exists
        var classData = snapshot.data!;
        if (!classData.data().toString().contains('students')) {
          return _buildEmptyState("No students enrolled.");
        }

        List<String> studentIds =
            List<String>.from(classData['students'] ?? []);

        if (studentIds.isEmpty) {
          return _buildEmptyState("No students enrolled.");
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: studentIds)
              .get(),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentBlue,
                  strokeWidth: 3,
                ),
              );
            }

            if (!studentSnapshot.hasData ||
                studentSnapshot.data!.docs.isEmpty) {
              return _buildEmptyState("No student details found.");
            }

            var students = studentSnapshot.data!.docs;
            return Column(
              children: [
                // Student count header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.accentBlue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "${students.length} Students",
                          style: TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var student = students[index];
                      String name = student['name'] ?? 'Unknown';
                      String email = student['email'] ?? 'No Email';

                      return Container(
                        margin: const EdgeInsets.fromLTRB(
                            16, 0, 16, 8), // Reduced bottom margin
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentBlue.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true, // Makes the tile more compact
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4), // Reduced vertical padding
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w500,
                              fontSize: 15, // Slightly smaller font
                            ),
                          ),
                          subtitle: Text(
                            email,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13, // Smaller font for email
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppColors.tertiaryText,
                              size: 18, // Smaller icon
                            ),
                            padding: EdgeInsets
                                .zero, // Remove padding from icon button
                            constraints: BoxConstraints(), // Remove constraints
                            onPressed: () {
                              _showStudentOptionsMenu(context, student);
                            },
                          ),
                          visualDensity: VisualDensity(
                              horizontal: 0,
                              vertical: -3), // Reduce the overall height
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: AppColors.tertiaryText,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showStudentOptionsMenu(BuildContext context, DocumentSnapshot student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.accentRed,
                    size: 20,
                  ),
                ),
                title: const Text(
                  "Remove from Class",
                  style: TextStyle(
                    color: AppColors.accentRed,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveConfirmation(context, student);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeStudentFromClass(String studentId) async {
    try {
      // Get the class document reference
      DocumentReference classDoc =
          FirebaseFirestore.instance.collection('classes').doc(classId);

      // Use a transaction to safely update the students list
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(classDoc);

        if (snapshot.exists) {
          List<dynamic> students = snapshot['students'] ?? [];

          if (students.contains(studentId)) {
            // Remove the student ID from the list
            students.remove(studentId);
            transaction.update(classDoc, {'students': students});
          }
        }
      });

      print("Student removed successfully!");
    } catch (e) {
      print("Error removing student: $e");
    }
  }

  void _showRemoveConfirmation(BuildContext context, DocumentSnapshot student) {
    String studentName = student['name'] ?? 'this student';
    String studentId = student.id; // Get the student ID

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.accentRed,
                size: 32,
              ),
              const SizedBox(height: 16),
              const Text(
                "Remove Student",
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Are you sure you want to remove $studentName from this class?",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(); // Close the dialog first
                      await _removeStudentFromClass(studentId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text("Remove"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
