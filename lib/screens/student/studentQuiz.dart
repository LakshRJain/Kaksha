import 'package:classcare/screens/student/Quiz_student.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:classcare/widgets/Colors.dart';
class Studentquiz extends StatefulWidget {
  final String classId;

  const Studentquiz({super.key, required this.classId});

  @override
  _StudentquizState createState() => _StudentquizState();
}

class _StudentquizState extends State<Studentquiz> {
  List<Map<String, dynamic>> _tests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTests();
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
              'startDateTime':
                  _convertTimestampToDateTime(doc['startDateTime']),
              'endDateTime': _convertTimestampToDateTime(doc['endDateTime']),
              'duration': doc['duration'],
            };
          }).toList();
          _isLoading = false;
        });
      }, onError: (error) {
        _handleError(error);
      });
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(dynamic error) {
    print("Error: $error");
    setState(() {
      _isLoading = false;
    });
    _showSnackBar('Error: $error', AppColors.accentRed);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: AppColors.primaryText),
        ),
        backgroundColor: backgroundColor.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  DateTime? _convertTimestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        print("Error parsing timestamp: $e");
        return null;
      }
    }

    return null;
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
            'Available Quizzes',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.accentBlue),
              onPressed: _fetchTests,
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section similar to GenerateMCQScreen
                Container(
                  margin: EdgeInsets.only(bottom: 24),
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
                          Icons.quiz_outlined,
                          color: AppColors.accentBlue,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Class Quizzes",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Take available quizzes for your class",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content section
                _isLoading
                    ? _buildLoadingIndicator()
                    : _tests.isEmpty
                        ? _buildEmptyState()
                        : _buildTestList(h, w),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: SpinKitWave(
          color: AppColors.accentBlue,
          size: 40.0,
        ),
      ),
    );
  }

  Widget _buildTestList(double h, double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            "Quiz List",
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ListView.builder(
          padding: EdgeInsets.zero,
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _tests.length,
          itemBuilder: (context, index) {
            return FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: index * 50),
              child: _buildTestCard(index, h, w),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTestCard(int index, double h, double w) {
    final test = _tests[index];
    final startDateTime = test['startDateTime'];
    final endDateTime = test['endDateTime'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(w * 0.03),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(w * 0.03),
          onTap: () => _showTestDetailsSheet(index, h, w),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: AppColors.accentPurple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        test['name'] ?? 'Unnamed Test',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${test['questions'].length} Q',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.event_outlined,
                  label: 'Starts:',
                  value: startDateTime != null
                      ? DateFormat('MMM dd, yyyy - hh:mm a')
                          .format(startDateTime)
                      : 'Not specified',
                  iconColor: AppColors.accentBlue,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.event_busy_outlined,
                  label: 'Ends:',
                  value: endDateTime != null
                      ? DateFormat('MMM dd, yyyy - hh:mm a').format(endDateTime)
                      : 'Not specified',
                  iconColor: AppColors.accentYellow,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Duration:',
                  value: '${test['duration'] ?? 'Unknown'} minutes',
                  iconColor: AppColors.accentGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTestDetailsSheet(int index, double h, double w) {
    final test = _tests[index];
    final startDateTime = test['startDateTime'];
    final endDateTime = test['endDateTime'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryText.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      color: AppColors.accentPurple,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    test['name'] ?? 'Unnamed Test',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                icon: Icons.event_outlined,
                label: 'Start Time',
                value: startDateTime != null
                    ? DateFormat('MMMM dd, yyyy - hh:mm a')
                        .format(startDateTime)
                    : 'Not Specified',
                iconColor: AppColors.accentBlue,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.event_busy_outlined,
                label: 'End Time',
                value: endDateTime != null
                    ? DateFormat('MMMM dd, yyyy - hh:mm a').format(endDateTime)
                    : 'Not Specified',
                iconColor: AppColors.accentYellow,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: '${test['duration'] ?? 'Unknown'} minutes',
                iconColor: AppColors.accentGreen,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.question_mark_outlined,
                label: 'Total Questions',
                value: '${test['questions'].length}',
                iconColor: AppColors.accentPurple,
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: w * 0.8,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentBlue,
                        AppColors.accentPurple,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.primaryText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentTestScreen(
                            testId: test['id'],
                            classId: widget.classId,
                            testDetails: {},
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Start Quiz',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.only(top: 30),
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_late_outlined,
              color: AppColors.accentYellow,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Quizzes Available',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Check back later or contact your instructor',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}