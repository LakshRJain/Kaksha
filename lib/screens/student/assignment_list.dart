import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:classcare/screens/student/assignment_card.dart';
import 'package:classcare/widgets/Colors.dart';
class AssignmentList extends StatefulWidget {
  final String classId;

  const AssignmentList({super.key, required this.classId});

  @override
  _AssignmentListState createState() => _AssignmentListState();
}

class _AssignmentListState extends State<AssignmentList> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {  // Fix: Check if index is changing
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.classId)
            .collection('assignments')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No assignments available"));
          }

          var now = DateTime.now();
          List<QueryDocumentSnapshot> upcoming = [];
          List<QueryDocumentSnapshot> past = [];

          for (var doc in snapshot.data!.docs) {
            var assignment = doc.data() as Map<String, dynamic>;
            var dueDate = DateTime.parse(assignment['dueDate']);

            if (dueDate.isAfter(now)) {
              upcoming.add(doc);
            } else {
              past.add(doc);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Tab Bar Style
              Container(
                margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                height: 48,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 30, 29, 29), // Grey background for the tab bar
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildTab("Upcoming", 0),
                    _buildTab("Past", 1),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSection(upcoming, "No upcoming assignments", context, widget.classId),
                    _buildSection(past, "No past assignments", context, widget.classId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Custom Tab Builder with Blue Border Indicator
  // Custom Tab Builder with Blue Border Indicator
Widget _buildTab(String title, int index) {
  return Expanded(
    child: GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {
          _currentIndex = index;  // Fix: Update index on tap
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),  // Smooth transition
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: _currentIndex == index
              ? Border.all(color: AppColors.accentBlue, width: 2) // Blue border for selected tab
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: _currentIndex == index ? AppColors.accentBlue : Colors.white,  // 🔄 Change here
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    ),
  );
}


  Widget _buildSection(List<QueryDocumentSnapshot> assignments, String emptyMessage, BuildContext context, String classId) {
    if (assignments.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView(
      children: assignments.map((doc) => AssignmentCard(assignment: doc, classId: classId)).toList(),
    );
  }
}
