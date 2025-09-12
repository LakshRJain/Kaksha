import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:classcare/widgets/Colors.dart';

class AssignmentDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot assignment;
  final String classId;
  const AssignmentDetailPage(
      {super.key, required this.assignment, required this.classId});
  @override
  _AssignmentDetailPageState createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  bool _isSubmitting = false, _isSubmitted = false, _hasAnalysisResult = false;
  PlatformFile? _pickedFile;
  String? _filePath, _submittedFileUrl, _submittedFileName, _marks, _feedback;
  final _theme = {
    'primary': Color.fromARGB(255, 125, 225, 130),
    'accent': const Color(0xFF03DAC6),
    'background': const Color(0xFF121212),
    'surface': const Color(0xFF1E1E1E),
    'card': const Color(0xFF252525),
    'error': const Color(0xFFCF6679),
    'success': const Color(0xFF4CAF50),
    'warning': const Color(0xFFFFA000),
    'textPrimary': Colors.white,
    'textSecondary': Colors.white70,
  };

  @override
  void initState() {
    super.initState();
    _checkSubmissionStatus();
  }

  Future<void> _checkSubmissionStatus() async {
    try {
      String studentId = FirebaseAuth.instance.currentUser!.uid;
      var submissionDoc = await FirebaseFirestore.instance
          .collection(
              'classes/${widget.classId}/assignments/${widget.assignment['assignmentId']}/submissions')
          .doc(studentId)
          .get();

      if (submissionDoc.exists) {
        setState(() {
          _isSubmitted = true;
          _submittedFileUrl = submissionDoc['fileUrl'];
          _submittedFileName =
              _submittedFileUrl?.split('/').last ?? "Submitted File";

          if (submissionDoc.data()!.containsKey('analysisResult')) {
            var analysisResult = submissionDoc['analysisResult'];
            _hasAnalysisResult = true;

            if (analysisResult is Map<String, dynamic>) {
              _marks = analysisResult['marks'];
              _feedback = analysisResult['feedback'];
            } else if (analysisResult is String) {
              final parts = analysisResult.split('_');
              _marks = parts[0].trim();
              _feedback =
                  parts.length > 1 ? parts[1].trim() : 'No feedback provided';
            }
          }
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> downloadFile(String fileUrl) async {
    try {
      await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar("Download failed: $e", _theme['error']!);
    }
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
          _filePath = result.files.first.path;
        });
      } else {
        _showSnackBar('No file selected', _theme['card']!);
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', _theme['error']!);
    }
  }

  void addToGoogleCalendar() async {
    var data = widget.assignment.data() as Map<String, dynamic>;
    String dueDate = data['dueDate'] ?? "";
    if (dueDate.isEmpty) {
      _showSnackBar("Due date not available", _theme['warning']!);
      return;
    }

    String title = Uri.encodeComponent(data['title'] ?? "No Title");
    String description =
        Uri.encodeComponent(data['description'] ?? "No Description");
    DateTime dueDateTime = DateTime.parse(dueDate);
    String formattedDate =
        "${dueDateTime.toUtc().toIso8601String().replaceAll("-", "").replaceAll(":", "").split(".")[0]}Z";
    String calendarUrl =
        "https://www.google.com/calendar/render?action=TEMPLATE&text=$title&details=$description&dates=$formattedDate/$formattedDate";

    try {
      await launchUrl(Uri.parse(calendarUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar("Could not open Calendar", _theme['error']!);
    }
  }

  Future<void> uploadSubmission() async {
    if (_pickedFile == null || _filePath == null) {
      _showSnackBar('Please select a file', _theme['warning']!);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String studentId = FirebaseAuth.instance.currentUser!.uid;
      String studentName = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get()
          .then((doc) => doc['name'] ?? 'No name found');

      Reference storageRef = FirebaseStorage.instance.ref().child(
          'classes/${widget.classId}/assignments/${widget.assignment['assignmentId']}/student/${_pickedFile!.name}');

      UploadTask uploadTask = kIsWeb
          ? storageRef.putData(_pickedFile!.bytes!)
          : storageRef.putFile(File(_filePath!));

      TaskSnapshot snapshot = await uploadTask;
      String fileUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection(
              'classes/${widget.classId}/assignments/${widget.assignment['assignmentId']}/submissions')
          .doc(studentId)
          .set({
        'studentName': studentName,
        'studentId': studentId,
        'fileUrl': fileUrl,
        'submittedAt': Timestamp.now(),
      });

      setState(() {
        _isSubmitted = true;
        _submittedFileUrl = fileUrl;
        _submittedFileName = _pickedFile!.name;
        _pickedFile = _filePath = null;
      });

      _showSnackBar('Assignment submitted successfully!', _theme['success']!);
    } catch (e) {
      _showSnackBar('Submission failed: $e', _theme['error']!);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showAnalysisDetailsDialog() {
    final marksController = TextEditingController(text: _marks);
    final feedbackController = TextEditingController(text: _feedback);
    bool isExpandedView = false;
    double fontSize = 15; // Default font size

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _theme['card'],
          title: Text(
            "Assignment Analysis",
            style: TextStyle(
                color: _theme['textPrimary'], fontWeight: FontWeight.w600),
          ),
          content: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isExpandedView
                ? MediaQuery.of(context).size.width * 0.85
                : null,
            height: isExpandedView
                ? MediaQuery.of(context).size.height * 0.7
                : null,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _theme['surface'],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentBlue.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Marks:",
                          style: TextStyle(
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: marksController,
                          style: TextStyle(
                              color: _theme['textPrimary'], fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Enter marks',
                            hintStyle:
                                TextStyle(color: _theme['textSecondary']),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.accentBlue.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  const BorderSide(color: AppColors.accentBlue),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: _theme['background'],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Feedback:",
                        style: TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      TextButton.icon(
                        icon: Icon(
                          isExpandedView
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          size: 18,
                          color: AppColors.accentBlue,
                        ),
                        label: Text(
                          isExpandedView ? "Compact View" : "Expand",
                          style: const TextStyle(
                            color: AppColors.accentBlue,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            isExpandedView = !isExpandedView;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: _theme['background'],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentBlue.withOpacity(0.5),
                      ),
                    ),
                    height: isExpandedView ? 350 : 150,
                    child: TextField(
                      controller: feedbackController,
                      style: TextStyle(
                          color: _theme['textSecondary'], fontSize: fontSize),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Enter feedback',
                        hintStyle: TextStyle(color: _theme['textTertiary']),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  if (isExpandedView)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.text_increase, size: 16),
                              label: const Text("Increase Font"),
                              onPressed: () {
                                setState(() {
                                  fontSize += 2;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentBlue,
                                side: BorderSide(
                                    color:
                                        AppColors.accentBlue.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.text_decrease, size: 16),
                              label: const Text("Decrease Font"),
                              onPressed: () {
                                setState(() {
                                  fontSize -= 2;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentBlue,
                                side: BorderSide(
                                    color:
                                        AppColors.accentBlue.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                  foregroundColor: _theme['textSecondary']),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () {
                // Here you would handle any saving logic if needed
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: _theme['textPrimary'],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("OK"),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildAnalysisResultSection(double w, double h) {
    if (!_hasAnalysisResult) return Container();
    return Container(
      margin: EdgeInsets.symmetric(vertical: h * 0.01),
      decoration: BoxDecoration(
        color: _theme['card'],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: AppColors.accentBlue, size: w * 0.06),
                SizedBox(width: w * 0.02),
                Text("Assignment Analysis",
                    style: TextStyle(
                        fontSize: w * 0.045,
                        fontWeight: FontWeight.bold,
                        color: _theme['textPrimary'])),
              ],
            ),
            Divider(
                color: _theme['accent']!.withOpacity(0.3),
                thickness: 1,
                height: h * 0.03),
            Row(
              children: [
                Icon(Icons.grade_outlined, color: Colors.amber, size: w * 0.05),
                SizedBox(width: w * 0.02),
                Text("Marks: ${_marks ?? 'Not available'}",
                    style: TextStyle(
                        fontSize: w * 0.035,
                        fontWeight: FontWeight.w500,
                        color: _theme['textPrimary'])),
              ],
            ),
            SizedBox(height: h * 0.01),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showAnalysisDetailsDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors.accentBlue),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.accentBlue),
                    SizedBox(width: 8),
                    Text("View Full Analysis",
                        style: TextStyle(color: AppColors.accentBlue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    var data = widget.assignment.data() as Map<String, dynamic>;
    String title = data['title'] ?? "No Title";
    String description = data['description'] ?? "No Description";
    String dueDate = data['dueDate'] ?? "No Due Date";
    String? fileUrl = data['fileUrl'];

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _theme['background'],
        primaryColor: _theme['primary'],
        colorScheme: ColorScheme.dark(
          primary: _theme['primary']!,
          secondary: _theme['accent']!,
          surface: _theme['surface']!,
          error: _theme['error']!,
        ),
        cardColor: _theme['card'],
        dividerColor: Colors.white24,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: _theme['textPrimary']),
          bodyMedium: TextStyle(color: _theme['textSecondary']),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(title,
              style: TextStyle(
                  fontSize: w * 0.045,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          backgroundColor: _theme['surface'],
          foregroundColor: _theme['textPrimary'],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_theme['background']!, Color(0xFF1A1A1A)],
            ),
          ),
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(w * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        vertical: h * 0.015, horizontal: w * 0.04),
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
                        Icon(Icons.calendar_today_outlined,
                            size: w * 0.05, color: _theme['textPrimary']),
                        SizedBox(width: w * 0.02),
                        Text("Due: $dueDate",
                            style: TextStyle(
                                fontSize: w * 0.035,
                                fontWeight: FontWeight.w500,
                                color: _theme['textPrimary'],
                                letterSpacing: 0.3)),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.add_alert_outlined,
                              color: _theme['textPrimary']),
                          onPressed: addToGoogleCalendar,
                          tooltip: 'Add to Calendar',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: h * 0.02),
                  Container(
                    decoration: BoxDecoration(
                      color: _theme['card'],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(w * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description_outlined,
                                  color: AppColors.accentBlue, size: w * 0.06),
                              SizedBox(width: w * 0.02),
                              Text("Assignment Details",
                                  style: TextStyle(
                                      fontSize: w * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: _theme['textPrimary'])),
                            ],
                          ),
                          Divider(
                              color: _theme['accent']!.withOpacity(0.3),
                              thickness: 1,
                              height: h * 0.03),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: h * 0.01),
                            child: Text(description,
                                style: TextStyle(
                                    fontSize: w * 0.035,
                                    color: _theme['textSecondary'],
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.02),
                  if (fileUrl != null)
                    Container(
                      decoration: BoxDecoration(
                        color: _theme['card'],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: w * 0.04, vertical: h * 0.01),
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.assignment_outlined,
                              size: w * 0.06, color: AppColors.accentBlue),
                        ),
                        title: Text("Assignment File",
                            style: TextStyle(
                                fontSize: w * 0.04,
                                color: AppColors.accentBlue)),
                        subtitle: Text("Click to download",
                            style: TextStyle(
                                fontSize: w * 0.03,
                                color: _theme['textSecondary'])),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.download_outlined,
                            size: w * 0.053,
                            color: AppColors.accentBlue,
                          ),
                          // label: Text(""),
                          onPressed: () => downloadFile(fileUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 56, 55, 55),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: h * 0.02),
                  Container(
                    decoration: BoxDecoration(
                      color: _theme['card'],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(w * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isSubmitted
                                    ? Icons.check_circle_outline
                                    : Icons.pending_outlined,
                                color: _isSubmitted
                                    ? AppColors.accentBlue
                                    : AppColors.accentYellow,
                                size: w * 0.06,
                              ),
                              SizedBox(width: w * 0.02),
                              Text(
                                _isSubmitted
                                    ? "Submitted"
                                    : "Pending Submission",
                                style: TextStyle(
                                  fontSize: w * 0.045,
                                  fontWeight: FontWeight.bold,
                                  color: _isSubmitted
                                      ? AppColors.accentBlue
                                      : AppColors.accentYellow,
                                ),
                              ),
                            ],
                          ),
                          Divider(
                              color: (_isSubmitted
                                      ? _theme['success']
                                      : _theme['warning'])!
                                  .withOpacity(0.3),
                              thickness: 1,
                              height: h * 0.03),
                          if (!_isSubmitted) ...[
                            Container(
                              padding: EdgeInsets.all(w * 0.04),
                              decoration: BoxDecoration(
                                color: _theme['surface'],
                                borderRadius: BorderRadius.circular(w * 0.02),
                                border: Border.all(
                                  color: _pickedFile != null
                                      ? _theme['accent']!.withOpacity(0.5)
                                      : Colors.grey.shade700,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Select Assignment File (PDF)",
                                      style: TextStyle(
                                          fontSize: w * 0.035,
                                          color: _theme['textSecondary'])),
                                  SizedBox(height: h * 0.01),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _pickedFile?.name ??
                                              "No file selected",
                                          style: TextStyle(
                                            color: _pickedFile != null
                                                ? _theme['textPrimary']
                                                : Colors.grey.shade500,
                                            fontSize: w * 0.03,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: w * 0.02),
                                      OutlinedButton.icon(
                                        onPressed: pickFile,
                                        icon: Icon(Icons.attach_file_outlined,
                                            size: w * 0.04),
                                        label: Text("Browse",
                                            style:
                                                TextStyle(fontSize: w * 0.03)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _theme['accent'],
                                          side: BorderSide(
                                              color: _theme['accent']!),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: h * 0.02),
                            SizedBox(
                              width: double.infinity,
                              height: h * 0.06,
                              child: ElevatedButton(
                                onPressed:
                                    _isSubmitting ? null : uploadSubmission,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentBlue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      _theme['primary']!.withOpacity(0.5),
                                  elevation: 4,
                                  shadowColor:
                                      _theme['primary']!.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                        height: w * 0.05,
                                        width: w * 0.05,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.upload_file_outlined,
                                              size: w * 0.05),
                                          SizedBox(width: w * 0.02),
                                          Text("Submit Assignment",
                                              style: TextStyle(
                                                  color: const Color.fromARGB(
                                                      255, 255, 255, 255),
                                                  fontSize: w * 0.05,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5)),
                                        ],
                                      ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: EdgeInsets.all(w * 0.03),
                              decoration: BoxDecoration(
                                color: _theme['surface'],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _theme['primary']!.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          _theme['success']!.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: w * 0.06,
                                        color: _theme['success']),
                                  ),
                                  SizedBox(width: w * 0.03),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            _submittedFileName ??
                                                "Submitted File",
                                            style: TextStyle(
                                                fontSize: w * 0.035,
                                                color: _theme['textPrimary']),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        SizedBox(height: 4),
                                        Text("Successfully submitted",
                                            style: TextStyle(
                                                fontSize: w * 0.03,
                                                color: _theme['success'])),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.download_outlined,
                                        size: w * 0.05,
                                        color: AppColors.accentGreen),
                                    onPressed: _submittedFileUrl != null
                                        ? () => downloadFile(_submittedFileUrl!)
                                        : null,
                                    tooltip: 'Download your submission',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_isSubmitted && _hasAnalysisResult) ...[
                    SizedBox(height: h * 0.02),
                    _buildAnalysisResultSection(w, h),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
