import 'package:classcare/screens/teacher/attendance_history.dart';
import 'package:classcare/screens/teacher/pdfgen.dart';
import 'package:classcare/screens/teacher/qpgen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classcare/screens/teacher/students_list.dart';
import 'package:classcare/screens/teacher/assignments_tab.dart';
import 'package:classcare/screens/teacher/chat_tab.dart';
import 'package:flutter/services.dart';
import 'package:classcare/screens/teacher/take_attendance_page.dart';
import 'package:classcare/screens/teacher/quiz_generate.dart';
// Refined color palette with subtle tones
class AppColors {
  // come ill show you cme ikk shiw you the appwha
  static const Color background = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF252525);
// Subtle accent colors
  static const Color accentBlue = Color(0xFF81A1C1);
  static const Color accentGreen = Color.fromARGB(255, 125, 225, 130);
  static const Color accentPurple = Color(0xFFB48EAD);
  static const Color accentYellow = Color(0xFFEBCB8B);
  static const Color accentRed = Color(0xFFBF616A);

  // Text colors
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color(0xFFAAAAAA);
  static const Color tertiaryText = Color(0xFF757575);
}

class ClassDetailPage extends StatefulWidget {
  final String classId;
  final String className;

  const ClassDetailPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  _ClassDetailPageState createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0; // Track the current tab index explicitly

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Add listener to update state when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index; // Update the current index
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakeAttendancePage(
          ClassId: widget.classId,
        ),
      ),
    );
  }

  Future<void> showRoomCodePopup() async {
    try {
      DocumentSnapshot classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      String joinCode = classDoc['joinCode'] ?? 'No Join Code Available';

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: EdgeInsets.all(24),
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
                Icon(
                  Icons.key_rounded,
                  color: AppColors.accentYellow,
                  size: 32,
                ),
                SizedBox(height: 16),
                Text(
                  "Class Join Code",
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        joinCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentBlue,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: joinCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Code copied to clipboard"),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor:
                                AppColors.accentGreen.withOpacity(0.8),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.copy, size: 18),
                      label: Text("Copy Code"),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentGreen,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceColor,
                        foregroundColor: AppColors.accentRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print("Error fetching join code: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not retrieve class code"),
          backgroundColor: AppColors.accentRed.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Function to handle tab selection
  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _tabController.animateTo(index);
    });
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
            widget.className,
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.surfaceColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: AppColors.accentBlue,
                      size: h * 0.04,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Class Options",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: h * 0.02,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.qr_code, color: AppColors.accentYellow),
                title: Text("Join Code",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: showRoomCodePopup,
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: AppColors.accentGreen),
                title: Text("Take Attendance",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: _navigateToAttendance,
              ),
              ListTile(
                leading: Icon(Icons.history, color: AppColors.accentPurple),
                title: Text("Attendance History",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AttendanceHistory(
                                classId: widget.classId,
                              )));
                },
              ),
              ListTile(
                leading: Icon(Icons.assignment, color: AppColors.accentBlue),
                title: Text("Generate Question Paper",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GenerateQuestionPaperScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.document_scanner,
                    color: const Color.fromARGB(255, 193, 129, 129)),
                title: Text("Generate Document",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GeneratePdfScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.quiz,
                    color: AppColors.accentYellow),
                title: Text("Quiz",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => quiz_generate(classId: widget.classId,)));
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Class header section
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
                borderRadius: BorderRadius.circular(w * 0.03),
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
                      Icons.school_outlined,
                      color: AppColors.accentBlue,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Class Management",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ],
              ),
            ),

            // Take Attendance Button - Simplified, cleaner design

            // Custom boxed tab bar with fixed segments
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(w * 0.03),
              ),
              child: Row(
                children: [
                  // Students Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 0
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _currentIndex == 0
                              ? Border.all(
                                  color: AppColors.accentBlue.withOpacity(0.5),
                                  width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: _currentIndex == 0
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Students",
                              style: TextStyle(
                                color: _currentIndex == 0
                                    ? AppColors.accentBlue
                                    : AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Assignments Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 1
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _currentIndex == 1
                              ? Border.all(
                                  color: AppColors.accentBlue.withOpacity(0.5),
                                  width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              color: _currentIndex == 1
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Assignments",
                              style: TextStyle(
                                color: _currentIndex == 1
                                    ? AppColors.accentBlue
                                    : AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Chat Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 2
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(w * 0.03),
                          border: _currentIndex == 2
                              ? Border.all(
                                  color: AppColors.accentBlue.withOpacity(0.5),
                                  width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: _currentIndex == 2
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Chat",
                              style: TextStyle(
                                color: _currentIndex == 2
                                    ? AppColors.accentBlue
                                    : AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(w * 0.03),
                ),
                clipBehavior: Clip.antiAlias,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    StudentsList(classId: widget.classId),  
                    AssignmentsTab(classId: widget.classId),
                    ChatTab(classId: widget.classId),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 