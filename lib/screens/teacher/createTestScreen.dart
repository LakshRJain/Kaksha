import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:classcare/widgets/Colors.dart';

class CreateTestScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTest;
  final String classId;

  const CreateTestScreen({required this.classId, this.existingTest, super.key});

  @override
  _CreateTestScreenState createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final TextEditingController _testNameController = TextEditingController();
  final TextEditingController _testDurationController = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
      List.generate(4, (index) => TextEditingController());
  int? _correctOption;
  String? _existingTestId;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  final Set<int> _expandedQuestions = {};

  @override
  void dispose() {
    _testNameController.dispose();
    _testDurationController.dispose();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingTest != null) {
      _existingTestId = widget.existingTest!['id'];
      _testNameController.text = widget.existingTest!['name'] ?? '';
      _questions = List.from(widget.existingTest!['questions'] ?? []);

      var startDateRaw = widget.existingTest!['startDateTime'];
      if (startDateRaw != null) {
        if (startDateRaw is Timestamp) {
          _startDate = startDateRaw.toDate();
        } else if (startDateRaw is String) {
          try {
            _startDate = DateTime.parse(startDateRaw);
          } catch (e) {
            print("Error parsing startDateTime string: $e");
          }
        } else if (startDateRaw is DateTime) {
          _startDate = startDateRaw;
        }

        _startTime =
            _startDate != null ? TimeOfDay.fromDateTime(_startDate!) : null;
      }

      var endDateRaw = widget.existingTest!['endDateTime'];
      if (endDateRaw != null) {
        if (endDateRaw is Timestamp) {
          _endDate = endDateRaw.toDate();
        } else if (endDateRaw is String) {
          try {
            _endDate = DateTime.parse(endDateRaw);
          } catch (e) {
            print("Error parsing endDateTime string: $e");
          }
        } else if (endDateRaw is DateTime) {
          _endDate = endDateRaw;
        }

        _endTime = _endDate != null ? TimeOfDay.fromDateTime(_endDate!) : null;
      }

      if (widget.existingTest!['duration'] != null) {
        _testDurationController.text =
            widget.existingTest!['duration'].toString();
      }
    }
  }

  void _showFullScreenQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
          ),
          child: Column(
            children: [
              AppBar(
                backgroundColor: AppColors.cardColor,
                leading: IconButton(
                  icon: Icon(Icons.close, color: AppColors.primaryText),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "Question ${index + 1}",
                  style: TextStyle(color: AppColors.primaryText),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade300),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteQuestion(index);
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentPurple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Question:",
                              style: TextStyle(
                                color: AppColors.accentPurple,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _questions[index]['question'],
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Options
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentBlue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Options:",
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            ...List.generate(
                              4,
                              (optIndex) => Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: optIndex ==
                                          _questions[index]['correct']
                                      ? AppColors.accentGreen.withOpacity(0.2)
                                      : AppColors.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: optIndex ==
                                            _questions[index]['correct']
                                        ? AppColors.accentGreen.withOpacity(0.5)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: optIndex ==
                                                _questions[index]['correct']
                                            ? AppColors.accentGreen
                                                .withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: optIndex ==
                                                  _questions[index]['correct']
                                              ? AppColors.accentGreen
                                              : AppColors.secondaryText,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${optIndex + 1}",
                                          style: TextStyle(
                                            color: optIndex ==
                                                    _questions[index]['correct']
                                                ? AppColors.accentGreen
                                                : AppColors.secondaryText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _questions[index]['options'][optIndex],
                                        style: TextStyle(
                                          color: optIndex ==
                                                  _questions[index]['correct']
                                              ? AppColors.accentGreen
                                              : AppColors.primaryText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: AppColors.cardColor,
              onSurface: AppColors.primaryText,
            ),
            dialogBackgroundColor: AppColors.surfaceColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _startTime ?? TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppColors.accentBlue,
                onPrimary: Colors.white,
                surface: AppColors.cardColor,
                onSurface: AppColors.primaryText,
              ),
              dialogBackgroundColor: AppColors.surfaceColor,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _startDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _startTime = pickedTime;
        });
      }
    }
  }

  Future<void> _selectEndDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: AppColors.cardColor,
              onSurface: AppColors.primaryText,
            ),
            dialogBackgroundColor: AppColors.surfaceColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _endTime ?? TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppColors.accentBlue,
                onPrimary: Colors.white,
                surface: AppColors.cardColor,
                onSurface: AppColors.primaryText,
              ),
              dialogBackgroundColor: AppColors.surfaceColor,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _endDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _endTime = pickedTime;
        });
      }
    }
  }

  Future<void> _importFromCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String csvString = await file.readAsString();

        List<List<dynamic>> csvTable = [];

        try {
          csvTable = const CsvToListConverter(
            eol: '\n',
            fieldDelimiter: '\t',
            textDelimiter: '"',
            shouldParseNumbers: false,
          ).convert(csvString);
        } catch (e) {
          print('First parsing method failed: $e');

          csvTable = csvString.split('\n').map((line) {
            return RegExp(r',(?=(?:[^"]"[^"]")[^"]$)')
                .allMatches(line)
                .map((match) => line.substring(match.start, match.end).trim())
                .toList();
          }).toList();
        }

        List<List<dynamic>> dataRows =
            csvTable.length > 1 ? csvTable.sublist(1) : csvTable;

        List<Map<String, dynamic>> importedQuestions = [];
        List<String> skippedRowReasons = [];

        for (var Trow in dataRows) {
          var row = Trow[0].split(',');

          if (row.length < 6) {
            skippedRowReasons.add(
                'Row skipped: Insufficient columns (found ${row.length}, expected at least 6)');
            continue;
          }

          if (row[0].toString().trim().isEmpty) {
            skippedRowReasons.add('Row skipped: Question is empty');
            continue;
          }

          bool anyEmptyOption = false;
          for (int i = 1; i < 5; i++) {
            if (row[i].toString().trim().isEmpty) {
              skippedRowReasons.add('Row skipped: Option ${i - 1} is empty');
              anyEmptyOption = true;
              break;
            }
          }
          if (anyEmptyOption) continue;

          String correctAnswer = row[5].toString().toLowerCase().trim();
          int correctOptionIndex = -1;

          switch (correctAnswer) {
            case '0':
              correctOptionIndex = 0;
              break;
            case '1':
              correctOptionIndex = 1;
              break;
            case '2':
              correctOptionIndex = 2;
              break;
            case '3':
              correctOptionIndex = 3;
              break;
            default:
              skippedRowReasons.add(
                  'Row skipped: Invalid correct answer "$correctAnswer" (must be 0, 1, 2, or 3)');
              continue;
          }

          Map<String, dynamic> question = {
            'question': row[0].toString().trim(),
            'options': [
              row[1].toString().trim(),
              row[2].toString().trim(),
              row[3].toString().trim(),
              row[4].toString().trim(),
            ],
            'correct': correctOptionIndex,
          };

          importedQuestions.add(question);
        }

        setState(() {
          _questions.addAll(importedQuestions);
        });

        String message =
            '${importedQuestions.length} questions imported successfully';
        if (skippedRowReasons.isNotEmpty) {
          message += '\n\nSkipped Rows:';
          for (var reason in skippedRowReasons) {
            message += '\n- $reason';
          }
        }

        _showSnackBar(message, AppColors.accentGreen);
      }
    } catch (e) {
      _showSnackBar(
          'Error importing CSV: ${e.toString()}', AppColors.accentRed);
      print('CSV Import Error: $e');
    }
  }

  void _addQuestion() {
    if (_questionController.text.isNotEmpty && _correctOption != null) {
      setState(() {
        _questions.add({
          'question': _questionController.text,
          'options':
              _optionControllers.map((controller) => controller.text).toList(),
          'correct': _correctOption,
        });
        _questionController.clear();
        for (var controller in _optionControllers) {
          controller.clear();
        }
        _correctOption = null;
      });
    } else {
      _showSnackBar('Please fill all fields and select a correct option',
          AppColors.accentYellow);
    }
  }

  Future<void> _submitTest() async {
    if (_testNameController.text.isEmpty) {
      _showSnackBar('Please enter a test name', AppColors.accentYellow);
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showSnackBar(
          'Please select start and end date/time', AppColors.accentYellow);
      return;
    }

    if (_testDurationController.text.isEmpty) {
      _showSnackBar(
          'Please enter test duration in minutes', AppColors.accentYellow);
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showSnackBar(
          'End date must be after start date', AppColors.accentYellow);
      return;
    }

    if (_questions.isEmpty) {
      _showSnackBar('Please add at least one question', AppColors.accentYellow);
      return;
    }

    try {
      Map<String, dynamic> testData = {
        'name': _testNameController.text,
        'questions': _questions,
        'startDateTime': Timestamp.fromDate(_startDate!),
        'endDateTime': Timestamp.fromDate(_endDate!),
        'duration': int.parse(_testDurationController.text),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_existingTestId != null && _existingTestId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.classId)
            .collection('tests')
            .doc(_existingTestId)
            .update(testData);

        testData['id'] = _existingTestId;
      } else {
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.classId)
            .collection('tests')
            .add(testData);

        testData['id'] = docRef.id;
      }

      Navigator.pop(context, testData);
    } catch (e) {
      _showSnackBar('Error saving test: ${e.toString()}', AppColors.accentRed);
    }
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
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
            'Create Test',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.022,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  margin: EdgeInsets.only(bottom: 16),
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
                            "Test Configuration",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Create questions and set parameters",
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

                // Test Info Section
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Test Information",
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Test Name
                      _buildTextField(
                        controller: _testNameController,
                        labelText: 'Test Name',
                        icon: Icons.text_fields,
                        color: AppColors.accentBlue,
                      ),
                      SizedBox(height: 12),

                      // Test Duration
                      _buildTextField(
                        controller: _testDurationController,
                        labelText: 'Duration (minutes)',
                        icon: Icons.timer,
                        color: AppColors.accentGreen,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),

                      // Date Selectors
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateTimeSelector(
                              label: 'Start',
                              icon: Icons.calendar_today,
                              color: AppColors.accentPurple,
                              dateTime: _startDate,
                              onTap: _selectStartDateTime,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildDateTimeSelector(
                              label: 'End',
                              icon: Icons.event_available,
                              color: AppColors.accentYellow,
                              dateTime: _endDate,
                              onTap: _selectEndDateTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Add Question Section
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Add Question",
                        style: TextStyle(
                          color: AppColors.accentPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Question text
                      _buildTextField(
                        controller: _questionController,
                        labelText: 'Question Text',
                        icon: Icons.help_outline,
                        color: AppColors.accentPurple,
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),

                      // Options
                      ...List.generate(4, (index) => _buildOptionTile(index)),

                      SizedBox(height: 16),

                      // Add Question Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addQuestion,
                          icon: Icon(Icons.add),
                          label: Text("Add Question"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPurple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          text: "Import CSV",
                          icon: Icons.upload_file,
                          color: AppColors.accentBlue,
                          onPressed: _importFromCSV,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          text: "Submit Test",
                          icon: Icons.check_circle,
                          color: AppColors.accentBlue,
                          onPressed: _submitTest,
                        ),
                      ),
                    ],
                  ),
                ),

                // Questions List
                if (_questions.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentYellow.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Questions (${_questions.length})",
                              style: TextStyle(
                                color: AppColors.accentYellow,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "Tap to expand",
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Questions list with fixed height
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 300,
                          ),
                          child: ListView.builder(
                            itemCount: _questions.length,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              return _buildQuestionTile(index);
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Empty state
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondaryText.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            color: AppColors.secondaryText,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No questions added yet",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Add questions manually or import from CSV",
                            style: TextStyle(
                              color: AppColors.tertiaryText,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required Color color,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.primaryText),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: AppColors.secondaryText),
          prefixIcon: Icon(icon, color: color),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _correctOption == index
              ? AppColors.accentGreen.withOpacity(0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Radio<int>(
            value: index,
            groupValue: _correctOption,
            onChanged: (int? value) {
              setState(() {
                _correctOption = value;
              });
            },
            activeColor: AppColors.accentGreen,
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _optionControllers[index],
              style: TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                hintText: 'Option ${index + 1}',
                hintStyle: TextStyle(color: AppColors.tertiaryText),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSelector({
    required String label,
    required IconData icon,
    required Color color,
    DateTime? dateTime,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    dateTime == null
                        ? "Select"
                        : DateFormat('dd MMM, HH:mm').format(dateTime),
                    style: TextStyle(
                      color: dateTime == null
                          ? AppColors.tertiaryText
                          : AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildQuestionTile(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withOpacity(0.3),
            Colors.indigo.shade900.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        title: Text(
          _questions[index]['question'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "Options: ${_questions[index]['options'].length}",
          style: TextStyle(color: Colors.grey.shade400),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.fullscreen,
                color: Colors.white70,
              ),
              onPressed: () => _showFullScreenQuestion(index),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade200),
              onPressed: () => _deleteQuestion(index),
            ),
          ],
        ),
        onTap: () => _showFullScreenQuestion(index),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required Color startColor,
    required Color endColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 150,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
