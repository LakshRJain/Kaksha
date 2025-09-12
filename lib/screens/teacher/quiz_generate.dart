import 'package:classcare/screens/teacher/generate_mcq_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add this dependency for date formatting
import 'package:classcare/screens/teacher/createTestScreen.dart';

class quiz_generate extends StatefulWidget {
  final String classId;

  const quiz_generate({
    super.key,
    required this.classId,
  });
  @override
  _quiz_generateState createState() => _quiz_generateState();
}

class _quiz_generateState extends State<quiz_generate>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tests = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize immediately
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Schedule the animation to start after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    _fetchTests();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchTests() async {
    try {
      setState(() {
        _isLoading = true;
      });

      FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('tests')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .listen((QuerySnapshot querySnapshot) {
        setState(() {
          _tests = querySnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': doc['name'] ?? 'Unnamed Test',
              'questions': doc['questions'] ?? [],
              'updatedAt': doc['updatedAt'],
              'startDateTime': convertTimestampToDateTime(doc['startDateTime']),
              'endDateTime': convertTimestampToDateTime(doc['endDateTime']),
              'duration': doc['duration'],
            };
          }).toList();
          _isLoading = false;
        });
      }, onError: (error) {
        print("Error fetching tests: $error");
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar(error.toString());
      });
    } catch (e) {
      print("Unexpected error: $e");
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  DateTime? convertTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        print("Error parsing timestamp string: $e");
        return null;
      }
    }
    return null;
  }

  void _showErrorSnackBar(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Error: $errorMessage',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _navigateToCreateTest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTestScreen(
          classId: widget.classId,
        ),
      ),
    );
  }

  void _editTest(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTestScreen(
          existingTest: _tests[index],
          classId: widget.classId,
        ),
      ),
    );
  }

  void _deleteTest(int index) async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Test',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${_tests[index]['name']}"? This action cannot be undone.',
            style: TextStyle(
              color: AppColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.accentBlue,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentRed.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.accentRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.classId)
            .collection('tests')
            .doc(_tests[index]['id'])
            .delete();
        _showSuccessSnackBar('Test deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting test: ${e.toString()}');
      }
    }
  }

  String _getTestStatus(Map<String, dynamic> test) {
    final now = DateTime.now();
    final startDate = test['startDateTime'];
    final endDate = test['endDateTime'];

    if (startDate == null || endDate == null) return 'Draft';

    if (now.isBefore(startDate)) {
      return 'Upcoming';
    } else if (now.isAfter(endDate)) {
      return 'Completed';
    } else {
      return 'Active';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return AppColors.accentBlue;
      case 'Active':
        return AppColors.accentPurple;
      case 'Completed':
        return AppColors.accentGreen;
      case 'Draft':
      default:
        return AppColors.accentYellow;
    }
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
            'Manage Tests',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.025,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: AppColors.primaryText,
              ),
              onPressed: _fetchTests,
              tooltip: 'Refresh tests',
            ),
            SizedBox(width: 8),
          ],
        ),
        body: FadeTransition(
          opacity: _animation,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                // Header section with improved design
                // Header section with improved design
                Container(
                  margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: EdgeInsets.all(h * 0.02),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withOpacity(0.3),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentBlue.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.quiz_outlined,
                          color: AppColors.primaryText,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Test Management",
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                overflow: TextOverflow.ellipsis, // Add this
                              ),
                              maxLines: 1, // Add this
                            ),
                            SizedBox(height: 4),
                            Wrap(
                              // Replace Row with Wrap
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "Create and manage assessments",
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 14,
                                    overflow: TextOverflow.ellipsis, // Add this
                                  ),
                                  maxLines: 1, // Add this
                                ),
                                if (!_isLoading) ...[
                                  Text(
                                    " • ",
                                    style: TextStyle(
                                      color: AppColors.accentBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${_tests.length} test${_tests.length != 1 ? 's' : ''}",
                                    style: TextStyle(
                                      color: AppColors.accentBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToCreateTest,
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: AppColors.background,
                            size: 20,
                          ),
                          label: Text(
                            'Create New Test',
                            style: TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: AppColors.background,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.accentGreen.withOpacity(0.5),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => GenerateMCQScreen()));
                          }, // Assuming this is another function
                          icon: Icon(
                            Icons.psychology_outlined,
                            color: AppColors.background,
                            size: 20,
                          ),
                          label: Text(
                            'Generate MCQ',
                            style: TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: AppColors.background,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.accentBlue.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Create Test Button with improved design

                // Tests List with improved cards
                Expanded(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: AppColors.accentBlue,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Loading tests...',
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _tests.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: EdgeInsets.all(16),
                                itemCount: _tests.length,
                                itemBuilder: (context, index) {
                                  return _buildTestTile(index, h, w);
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestTile(int index, double h, double w) {
    final test = _tests[index];
    final status = _getTestStatus(test);
    final statusColor = _getStatusColor(status);

    // Format dates if they exist
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    String startDateText = test['startDateTime'] != null
        ? dateFormat.format(test['startDateTime'])
        : 'Not scheduled';

    String durationText = '';
    if (test['duration'] != null) {
      int minutes = test['duration'];
      if (minutes >= 60) {
        int hours = minutes ~/ 60;
        int remainingMinutes = minutes % 60;
        durationText = '$hours hr';
        if (remainingMinutes > 0) {
          durationText += ' $remainingMinutes min';
        }
      } else {
        durationText = '$minutes min';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editTest(index),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test['name'] ?? 'Unnamed Test',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: AppColors.secondaryText,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${test['questions'].length} question${test['questions'].length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                              if (durationText.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: AppColors.tertiaryText,
                                    fontSize: 13,
                                  ),
                                ),
                                Icon(
                                  Icons.timer_outlined,
                                  color: AppColors.secondaryText,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  durationText,
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // Date information section
                if (test['startDateTime'] != null) ...[
                  SizedBox(height: 12),
                  Divider(height: 1, color: _getStatusColor(status)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        color: AppColors.secondaryText,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        startDateText,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action buttons
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      onPressed: () => _editTest(index),
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: AppColors.accentYellow,
                    ),
                    SizedBox(width: 8),
                    _buildActionButton(
                      onPressed: () => _deleteTest(index),
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: AppColors.accentRed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(
        icon,
        color: color,
        size: 16,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.quiz_outlined,
                color: AppColors.accentBlue.withOpacity(0.7),
                size: 64,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No tests created yet',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Create your first test to start assessing your students\' knowledge and progress.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToCreateTest,
              icon: Icon(Icons.add, size: 20),
              label: Text(
                'Create First Test',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.accentBlue.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
