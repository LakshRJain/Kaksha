import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:classcare/widgets/Colors.dart';

class AttendanceHistory extends StatefulWidget {
  final String classId;

  const AttendanceHistory({super.key, required this.classId});

  @override
  _AttendanceHistoryState createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<AttendanceHistory> {
  String? selectedDate;
  bool isExpanded = false;

  // Function to fetch attendance data from Firestore
  Stream<Map<String, dynamic>> fetchAttendanceHistory() async* {
    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('attendancehistory');

      // Check if the collection exists
      final snapshot = await collectionRef.get();
      if (snapshot.docs.isEmpty) {
        yield {}; // Return an empty map if no documents are found
      } else {
        yield* collectionRef.snapshots().map((snapshot) {
          final data = <String, dynamic>{};
          for (var doc in snapshot.docs) {
            data[doc.id] = doc.data();
          }
          return data;
        });
      }
    } catch (e) {
      print("Error fetching attendance history: $e");
      yield {}; // Return an empty map if any error occurs
    }
  }

  // Format date for better display (convert from "DD-MM-YYYY" to readable format)
  String formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        final date = DateTime(year, month, day);
        return DateFormat.yMMMMd()
            .format(date); // Returns "January 12, 2023" format
      }
    } catch (e) {
      print("Error parsing date: $e");
    }
    return dateStr; // Return original if parsing fails
  }

  // Count total students for a date
  int countStudents(Map<String, dynamic> dateData) {
    return dateData.length;
  }

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: w * 0.01,
        ),
        cardColor: AppColors.cardColor,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Attendance History",
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
        ),
        body: Column(
          children: [
            // Header Status Section
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.all(h * 0.018),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentBlue.withOpacity(0.2),
                    AppColors.accentPurple.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_edu,
                      color: AppColors.accentBlue,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Class Attendance Records",
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "View and analyze attendance patterns over time",
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Dates List Header
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    "Attendance Dates",
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  StreamBuilder<Map<String, dynamic>>(
                      stream: fetchAttendanceHistory(),
                      builder: (context, snapshot) {
                        final int totalDates =
                            snapshot.hasData ? snapshot.data!.length : 0;
                        return Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "$totalDates Days",
                            style: TextStyle(
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ),

            // Dates and Students List
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: fetchAttendanceHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentBlue,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: AppColors.secondaryText.withOpacity(0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No attendance records found",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Take attendance to see records here",
                            style: TextStyle(
                              color: AppColors.tertiaryText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final attendanceData = snapshot.data!;
                  // Sort dates in descending order (most recent first)
                  final sortedDates = attendanceData.keys.toList()
                    ..sort((a, b) {
                      try {
                        final aParts = a.split('-').map(int.parse).toList();
                        final bParts = b.split('-').map(int.parse).toList();
                        final aDate = DateTime(aParts[2], aParts[1], aParts[0]);
                        final bDate = DateTime(bParts[2], bParts[1], bParts[0]);
                        return bDate.compareTo(aDate); // Descending order
                      } catch (e) {
                        return 0;
                      }
                    });

                  return ListView.builder(
                    itemCount: sortedDates.length,
                    padding: EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final dateData =
                          attendanceData[date] as Map<String, dynamic>;
                      final isSelected = selectedDate == date;
                      final studentCount = countStudents(dateData);

                      return Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentBlue
                                    : AppColors.cardColor,
                                width: 1,
                              ),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                initiallyExpanded: isSelected,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    selectedDate = expanded ? date : null;
                                  });
                                },
                                tilePadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                collapsedShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                leading: Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accentPurple.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: AppColors.accentPurple,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  formatDate(date),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                subtitle: Text(
                                  "$studentCount students present",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                trailing: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accentGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "$studentCount",
                                    style: TextStyle(
                                      color: AppColors.accentGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                children: dateData.entries.map<Widget>((entry) {
                                  // Extract student information from complex keys
                                  final String entryKey = entry.key;
                                  final studentData = entry.value;

                                  if (studentData is! Map<String, dynamic>) {
                                    return SizedBox.shrink();
                                  }

                                  final studentName =
                                      studentData['name'] ?? 'Unknown';
                                  final attendanceTime =
                                      studentData['time'] ?? 'N/A';

                                  return Container(
                                    margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.accentGreen
                                            .withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      leading: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGreen
                                              .withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.accentGreen,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        studentName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: AppColors.secondaryText,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            attendanceTime,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
