import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class AssignmentDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot assignment;
  final String classId;

  const AssignmentDetailPage(
      {super.key, required this.assignment, required this.classId});

  @override
  _AssignmentDetailPageState createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  bool _isSubmitting = false;
  PlatformFile? _pickedFile;
  String? _filePath;
  bool _isSubmitted = false;
  String? _submittedFileUrl;
  String? _submittedFileName;
  // Added for analysis results
  bool _hasAnalysisResult = false;
  String? _marks;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _checkSubmissionStatus();
  }

  // Check if the assignment has been submitted by the student
  Future<void> _checkSubmissionStatus() async {
    try {
      String studentId = FirebaseAuth.instance.currentUser!.uid;

      var submissionSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('assignments')
          .doc(widget.assignment['assignmentId'])
          .collection('submissions')
          .doc(studentId)
          .get();

      if (submissionSnapshot.exists) {
        setState(() {
          _isSubmitted = true;
          _submittedFileUrl = submissionSnapshot['fileUrl'];
          _submittedFileName =
              _submittedFileUrl?.split('/').last ?? "Submitted File";

          // Check for analysis results
          if (submissionSnapshot.data()!.containsKey('analysisResult')) {
            var analysisResult = submissionSnapshot['analysisResult'];
            if (analysisResult is Map<String, dynamic>) {
              _hasAnalysisResult = true;
              _marks = analysisResult['marks'];
              _feedback = analysisResult['feedback'];
            } else if (analysisResult is String) {
              _hasAnalysisResult = true;
              // Parse the string format from teacher's screen
              final parts = analysisResult.split('_');
              _marks = parts[0].trim();
              _feedback =
                  parts.length > 1 ? parts[1].trim() : 'No feedback provided';
            }
          }
        });
      }
    } catch (e) {
      print("Error checking submission status: $e");
    }
  }

  Future<void> downloadFile(String fileUrl) async {
    final Uri uri = Uri.parse(fileUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void addToGoogleCalendar() async {
    var data = widget.assignment.data() as Map<String, dynamic>;
    String title = Uri.encodeComponent(data['title'] ?? "No Title");
    String description =
        Uri.encodeComponent(data['description'] ?? "No Description");
    String dueDate = data['dueDate'] ?? "";

    if (dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Due date not available")),
      );
      return;
    }

    // Convert dueDate to ISO format
    DateTime dueDateTime = DateTime.parse(dueDate);
    String formattedDueDate =
        "${dueDateTime.toUtc().toIso8601String().replaceAll("-", "").replaceAll(":", "").split(".")[0]}Z";

    String calendarUrl =
        "https://www.google.com/calendar/render?action=TEMPLATE"
        "&text=$title"
        "&details=$description"
        "&dates=$formattedDueDate/$formattedDueDate";

    Uri uri = Uri.parse(calendarUrl);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print("Error launching URL: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Calendar")),
      );
    }
  }

  Future<void> uploadSubmission() async {
    if (_pickedFile == null || _filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file before submitting')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String studentId = FirebaseAuth.instance.currentUser!.uid;
      String studentName = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get()
          .then((doc) => doc['name'] ?? 'No name found');

      String fileExtension = _pickedFile!.extension ?? 'pdf';

      Reference storageRef = FirebaseStorage.instance.ref().child(
          'classes/${widget.classId}/assignments/${widget.assignment['assignmentId']}/student/${_pickedFile!.name}');

      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = storageRef.putData(_pickedFile!.bytes!);
      } else {
        uploadTask = storageRef.putFile(File(_filePath!));
      }

      TaskSnapshot snapshot = await uploadTask;
      String fileUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('assignments')
          .doc(widget.assignment['assignmentId'])
          .collection('submissions')
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
        _pickedFile = null;
        _filePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit assignment: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // New method to show analysis details
  void _showAnalysisDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assignment Analysis'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Marks:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _marks ?? 'Not available',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Feedback:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _feedback ?? 'No feedback provided',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Method to build the analysis result section
  Widget _buildAnalysisResultSection(double screenWidth, double screenHeight) {
    if (!_hasAnalysisResult) {
      return Container();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assessment,
                  color: Theme.of(context).primaryColor,
                  size: screenWidth * 0.06,
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  "Assignment Analysis",
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),
            Row(
              children: [
                Icon(
                  Icons.grade,
                  color: Colors.amber,
                  size: screenWidth * 0.05,
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  "Marks: ${_marks ?? 'Not available'}",
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.01),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showAnalysisDetailsDialog,
                icon: Icon(Icons.info_outline),
                label: Text("View Full Analysis"),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    var data = widget.assignment.data() as Map<String, dynamic>;
    String title = data['title'] ?? "No Title";
    String description = data['description'] ?? "No Description";
    String dueDate = data['dueDate'] ?? "No Due Date";
    String? fileUrl = data['fileUrl'];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(fontSize: screenWidth * 0.05),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04), // Responsive padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Due Date Banner
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.015,
                  horizontal: screenWidth * 0.04,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: screenWidth * 0.05),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      "Due: $dueDate",
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02), // Responsive spacing

              // Description Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Description",
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Text(
                              description,
                              style: TextStyle(fontSize: screenWidth * 0.035),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: addToGoogleCalendar,
                        icon: Icon(
                          Icons.calendar_today,
                          size: screenWidth * 0.05,
                          color: Colors.white,
                        ),
                        label: Text(
                          "Add to Calendar",
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // File Download Section
              if (fileUrl != null)
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.assignment, size: screenWidth * 0.06),
                    title: Text("Assignment File",
                        style: TextStyle(fontSize: screenWidth * 0.04)),
                    subtitle: Text("Click to download",
                        style: TextStyle(fontSize: screenWidth * 0.03)),
                    trailing: IconButton(
                      icon: Icon(Icons.download, size: screenWidth * 0.05),
                      onPressed: () => downloadFile(fileUrl),
                    ),
                  ),
                ),

              SizedBox(height: screenHeight * 0.02),

              // Submission Status Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isSubmitted ? Icons.check_circle : Icons.pending,
                            color: _isSubmitted ? Colors.green : Colors.orange,
                            size: screenWidth * 0.06,
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Text(
                            _isSubmitted ? "Submitted" : "Pending Submission",
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                              color:
                                  _isSubmitted ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      if (!_isSubmitted) ...[
                        // File Selection Area
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.02),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _pickedFile?.name ?? "No file selected",
                                      style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: screenWidth * 0.03),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: pickFile,
                                    icon: Icon(Icons.attach_file,
                                        size: screenWidth * 0.05,
                                        color: Colors.white),
                                    label: Text("Choose File",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: screenWidth * 0.03)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        // Submit Button
                        FractionallySizedBox(
                          widthFactor: 1, // Makes it full width
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : uploadSubmission,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.02),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: screenWidth * 0.06,
                                    width: screenWidth * 0.06,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text("Submit Assignment",
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.045)),
                          ),
                        ),
                      ] else ...[
                        // Submitted File Section
                        ListTile(
                          leading: Icon(Icons.insert_drive_file,
                              size: screenWidth * 0.06),
                          title: Text(_submittedFileName ?? "Submitted File",
                              style: TextStyle(fontSize: screenWidth * 0.03)),
                          trailing: IconButton(
                            icon:
                                Icon(Icons.download, size: screenWidth * 0.05),
                            onPressed: _submittedFileUrl != null
                                ? () => downloadFile(_submittedFileUrl!)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Analysis Results Section (only shown if available)
              if (_isSubmitted && _hasAnalysisResult) ...[
                SizedBox(height: screenHeight * 0.02),
                _buildAnalysisResultSection(screenWidth, screenHeight),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
