import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:classcare/widgets/Colors.dart';

class StudentTestScreen extends StatefulWidget {
  final String testId;
  final String classId;
  final Map<String, dynamic> testDetails;

  const StudentTestScreen({
    super.key,
    required this.testId,
    required this.classId,
    required this.testDetails,
  });

  @override
  _StudentTestScreenState createState() => _StudentTestScreenState();
}

class _StudentTestScreenState extends State<StudentTestScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  Timer? _testTimer;
  int _remainingSeconds = 0;
  bool _isTestSubmitted = false;
  int _correctAnswers = 0;
  bool _isLoading = true;
  bool _hasAlreadyAttempted = false;
  String? _studentId;
  Map<String, dynamic>? _previousAttemptData;

  // App switch tracking
  int _switchCount = 0;
  final bool _isActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _studentId = FirebaseAuth.instance.currentUser?.uid;
    _resetSwitchCounter();
    _checkTestAttempt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _testTimer?.cancel();
    super.dispose();
  }

  Future<void> _resetSwitchCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('switch_count', 0);
    setState(() {
      _switchCount = 0;
    });
  }

  Future<void> _incrementSwitchCount() async {
    if (!_isActive) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _switchCount++;
    });
    await prefs.setInt('switch_count', _switchCount);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isActive) {
      _incrementSwitchCount();
    }
  }

  Future<void> _checkTestAttempt() async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('tests')
          .doc(widget.testId)
          .collection('results')
          .where('studentId', isEqualTo: _studentId)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        setState(() {
          _hasAlreadyAttempted = true;
          _previousAttemptData = result.docs.first.data();
          _isLoading = false;
        });
      } else {
        _fetchTestDetails();
      }
    } catch (e) {
      print('Error checking test attempt: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error checking test attempt: $e', AppColors.accentRed);
    }
  }

  Future<void> _fetchTestDetails() async {
    try {
      DocumentSnapshot testDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (testDoc.exists) {
        setState(() {
          _questions = List<Map<String, dynamic>>.from(testDoc['questions']);
          _selectedAnswers = List.filled(_questions.length, null);
          _remainingSeconds = testDoc['duration'] * 60;
          _isLoading = false;
        });

        _startTimer();
      }
    } catch (e) {
      print('Error fetching test details: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading test: $e', AppColors.accentRed);
    }
  }

  void _startTimer() {
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _submitTest();
          timer.cancel();
        }
      });
    });
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _submitTest() {
    _testTimer?.cancel();
    _correctAnswers = _questions.asMap().entries.where((entry) {
      int index = entry.key;
      Map<String, dynamic> question = entry.value;
      return _selectedAnswers[index] == question['correct'];
    }).length;

    setState(() {
      _isTestSubmitted = true;
    });

    _saveTestResult();
  }

  Future<void> _saveTestResult() async {
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('tests')
          .doc(widget.testId)
          .collection('results')
          .add({
        'studentId': _studentId,
        'score': _correctAnswers,
        'totalQuestions': _questions.length,
        'selectedAnswers': _selectedAnswers,
        'submittedAt': FieldValue.serverTimestamp(),
        'appSwitchCount': _switchCount,
      });
    } catch (e) {
      print('Error saving test result: $e');
      _showSnackBar('Error submitting test: $e', AppColors.accentRed);
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.background,
        ),
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppColors.accentBlue,
            ),
          ),
        ),
      );
    }

    if (_hasAlreadyAttempted) {
      return _buildAlreadyAttemptedScreen();
    }

    if (_isTestSubmitted) {
      return _buildResultScreen(h, w);
    }

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
            'Quiz',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _remainingSeconds <= 60
                      ? AppColors.accentRed.withOpacity(0.7)
                      : AppColors.accentBlue.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: AppColors.primaryText,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  margin: EdgeInsets.only(bottom: 24),
                  padding: EdgeInsets.all(h * 0.018),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPurple.withOpacity(0.2),
                        AppColors.accentBlue.withOpacity(0.2),
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
                          color: AppColors.accentPurple.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.quiz_outlined,
                          color: AppColors.accentPurple,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.testDetails['title'] ?? "Quiz",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
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

                // Question Card
                _buildQuestionCard(w),

                SizedBox(height: 20),

                // Navigation Buttons
                _buildNavigationButtons(w),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(double w) {
    if (_questions.isEmpty) return Container();
    
    final currentQuestion = _questions[_currentQuestionIndex];
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(w * 0.03),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Question ${_currentQuestionIndex + 1}",
            style: TextStyle(
              color: AppColors.accentBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accentBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              currentQuestion['question'],
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 20),
          
          // Options
          ...List.generate(
            currentQuestion['options'].length,
            (index) => _buildOptionTile(
              currentQuestion['options'][index],
              index,
              _selectedAnswers[_currentQuestionIndex] == index,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(String option, int optionIndex, bool isSelected) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accentPurple.withOpacity(0.2) : AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.accentPurple : AppColors.surfaceColor,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.accentPurple : AppColors.surfaceColor,
            border: Border.all(
              color: isSelected ? AppColors.accentPurple : AppColors.secondaryText,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              optionIndex.toString(),
              style: TextStyle(
                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        title: Text(
          option,
          style: TextStyle(
            color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
          ),
        ),
        onTap: () => _selectAnswer(optionIndex),
      ),
    );
  }

  Widget _buildNavigationButtons(double w) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous Button
        Container(
          width: w * 0.2,
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
            onPressed: _previousQuestion,
          ),
        ),
        
        // Submit Button
        Container(
          width: w * 0.45,
          height: 45,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentGreen,
                AppColors.accentGreen.withOpacity(0.7),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGreen.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _submitTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.primaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Text(
                  'Submit Quiz',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Next Button
        Container(
          width: w * 0.2,
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_forward, color: AppColors.primaryText),
            onPressed: _nextQuestion,
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen(double h, double w) {
    double scorePercentage = (_correctAnswers / _questions.length) * 100;
    bool isPassing = scorePercentage >= 60;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: w * 0.01,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Test Result',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
        ),
        body: Center(
          child: Container(
            width: w * 0.85,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isPassing
                    ? AppColors.accentGreen.withOpacity(0.2)
                    : AppColors.accentRed.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: isPassing
                  ? AppColors.accentGreen.withOpacity(0.3)
                  : AppColors.accentRed.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Result icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPassing
                      ? AppColors.accentGreen.withOpacity(0.1)
                      : AppColors.accentRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassing ? Icons.check_circle : Icons.info,
                    color: isPassing ? AppColors.accentGreen : AppColors.accentRed,
                    size: 50,
                  ),
                ),
                SizedBox(height: 24),
                
                // Score text
                Text(
                  'Your Score',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                
                // Score number
                Text(
                  '$_correctAnswers / ${_questions.length}',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                
                // Percentage
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPassing
                      ? AppColors.accentGreen.withOpacity(0.2)
                      : AppColors.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${scorePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isPassing ? AppColors.accentGreen : AppColors.accentRed,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                
                // App switch info
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _switchCount > 3
                      ? AppColors.accentYellow.withOpacity(0.1)
                      : AppColors.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _switchCount > 3
                        ? AppColors.accentYellow.withOpacity(0.3)
                        : AppColors.surfaceColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _switchCount > 3 ? Icons.warning : Icons.smartphone,
                        color: _switchCount > 3 ? AppColors.accentYellow : AppColors.secondaryText,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'App Switches: $_switchCount',
                        style: TextStyle(
                          color: _switchCount > 3 ? AppColors.accentYellow : AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Back button
                Container(
                  width: w * 0.6,
                  height: 45,
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
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.primaryText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back to Tests',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
  Widget _buildAlreadyAttemptedScreen() {
    if (_previousAttemptData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blue.shade200,
          ),
        ),
      );
    }

    final score = _previousAttemptData!['score'] ?? 0;
    final totalQuestions = _previousAttemptData!['totalQuestions'] ?? 1;
    final percentage = (score / totalQuestions) * 100;
    final appSwitchCount = _previousAttemptData!['appSwitchCount'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Test Results',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: percentage >= 60
                    ? Colors.green.shade200.withOpacity(0.3)
                    : Colors.red.shade200.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_turned_in,
                color: Colors.blue,
                size: 60,
              ),
              const SizedBox(height: 20),
              const Text(
                'You have already attempted this test.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Your Score:',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$score / $totalQuestions',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: percentage >= 60
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'App Switches: $appSwitchCount',
                style: TextStyle(
                  color: appSwitchCount > 3 ? Colors.red : Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Back to Tests'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
