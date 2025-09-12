import 'package:flutter/material.dart';
import 'package:classcare/widgets/teacher_assignment_list.dart';
import 'package:classcare/widgets/assignment_upload_widget.dart';

import 'package:classcare/widgets/Colors.dart';

class AssignmentsTab extends StatefulWidget {
  final String classId;

  const AssignmentsTab({super.key, required this.classId});

  @override
  _AssignmentsTabState createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _assignmentTabController;
  int _currentAssignmentTab = 0; // Track the current selected tab

  @override
  void initState() {
    super.initState();
    _assignmentTabController = TabController(length: 2, vsync: this);

    // Add listener to update state when tab changes
    _assignmentTabController.addListener(() {
      if (!_assignmentTabController.indexIsChanging) {
        setState(() {
          _currentAssignmentTab = _assignmentTabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _assignmentTabController.dispose();
    super.dispose();
  }

  // Function to handle tab selection
  void _selectAssignmentTab(int index) {
    setState(() {
      _currentAssignmentTab = index;
      _assignmentTabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Custom boxed tab bar for assignments
          Container(
            margin: EdgeInsets.only(bottom: 12),
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Current Assignments Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectAssignmentTab(0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _currentAssignmentTab == 0
                            ? AppColors.cardColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _currentAssignmentTab == 0
                            ? Border.all(
                                color: AppColors.accentBlue.withOpacity(0.5),
                                width: 1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          "Current Assignments",
                          style: TextStyle(
                            color: _currentAssignmentTab == 0
                                ? AppColors.accentBlue
                                : AppColors.secondaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Past Assignments Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectAssignmentTab(1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _currentAssignmentTab == 1
                            ? AppColors.cardColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _currentAssignmentTab == 1
                            ? Border.all(
                                color: AppColors.accentBlue.withOpacity(0.5),
                                width: 1)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          "Past Assignments",
                          style: TextStyle(
                            color: _currentAssignmentTab == 1
                                ? AppColors.accentBlue
                                : AppColors.secondaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Assignment list content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: TabBarView(
                controller: _assignmentTabController,
                children: [
                  AssignmentList(classId: widget.classId, isCurrent: true),
                  AssignmentList(classId: widget.classId, isCurrent: false),
                ],
              ),
            ),
          ),

          // Upload assignment button
          Container(
            margin: EdgeInsets.only(top: 16),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AssignmentUploadWidget(classId: widget.classId),
                  ),
                );
              },
              icon: Icon(Icons.upload_file, size: 18),
              label: Text(
                "Upload Assignment",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
