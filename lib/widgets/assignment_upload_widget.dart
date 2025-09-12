import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:classcare/widgets/Colors.dart';

class AssignmentUploadWidget extends StatefulWidget {
  final String classId;

  const AssignmentUploadWidget({super.key, required this.classId});

  @override
  _AssignmentUploadWidgetState createState() => _AssignmentUploadWidgetState();
}

class _AssignmentUploadWidgetState extends State<AssignmentUploadWidget> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _dueDate;
  PlatformFile? _pickedFile;
  String? _filePath;
  PlatformFile? _rubricFile;
  String? _rubricFilePath;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(withReadStream: true);

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
          _filePath = result.files.first.path;
        });
      } else {
        _showSnackBar(
            'No file selected', AppColors.accentYellow.withOpacity(0.8));
      }
    } catch (e) {
      _showSnackBar(
          'Error picking file: $e', AppColors.accentRed.withOpacity(0.8));
    }
  }

  Future<void> pickRubric() async {
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(withReadStream: true);

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _rubricFile = result.files.first;
          _rubricFilePath = result.files.first.path;
        });
      } else {
        _showSnackBar(
            'No rubric file selected', AppColors.accentYellow.withOpacity(0.8));
      }
    } catch (e) {
      _showSnackBar('Error picking rubric file: $e',
          AppColors.accentRed.withOpacity(0.8));
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> uploadAssignment() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _dueDate == null ||
        _pickedFile == null ||
        _rubricFile == null ||
        _filePath == null ||
        _rubricFilePath == null) {
      _showSnackBar('Please complete all fields and upload files',
          AppColors.accentYellow.withOpacity(0.8));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String assignmentId = FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('assignments')
          .doc()
          .id;

      Reference rubricStorageRef = FirebaseStorage.instance.ref().child(
          'classes/${widget.classId}/assignments/$assignmentId/rubric.pdf');
      UploadTask rubricUploadTask;

      if (kIsWeb) {
        rubricUploadTask = rubricStorageRef.putData(_rubricFile!.bytes!);
      } else {
        rubricUploadTask = rubricStorageRef.putFile(File(_rubricFilePath!));
      }

      TaskSnapshot rubricSnapshot = await rubricUploadTask;
      String rubricUrl = await rubricSnapshot.ref.getDownloadURL();

      Reference assignmentStorageRef = FirebaseStorage.instance.ref().child(
          'classes/${widget.classId}/assignments/$assignmentId/teacher_assignment.pdf');
      UploadTask assignmentUploadTask;

      if (kIsWeb) {
        assignmentUploadTask =
            assignmentStorageRef.putData(_pickedFile!.bytes!);
      } else {
        assignmentUploadTask = assignmentStorageRef.putFile(File(_filePath!));
      }

      TaskSnapshot assignmentSnapshot = await assignmentUploadTask;
      String assignmentUrl = await assignmentSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('assignments')
          .doc(assignmentId)
          .set({
        'assignmentId': assignmentId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'dueDate': DateFormat('yyyy-MM-dd').format(_dueDate!),
        'uploadedBy': FirebaseAuth.instance.currentUser!.uid,
        'rubricUrl': rubricUrl,
        'fileUrl': assignmentUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Assignment uploaded successfully!',
          AppColors.accentGreen.withOpacity(0.8));

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _dueDate = null;
        _pickedFile = null;
        _rubricFile = null;
        _filePath = null;
        _rubricFilePath = null;
      });
    } catch (e) {
      _showSnackBar('Failed to upload assignment: $e',
          AppColors.accentRed.withOpacity(0.8));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Custom styled text field matching the first code's design
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
    int maxLines = 1,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.accentBlue.withOpacity(0.3), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: AppColors.primaryText),
        decoration: InputDecoration(
          labelText: label + (isOptional ? " (Optional)" : ""),
          labelStyle: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
          ),
          floatingLabelStyle: TextStyle(
            color: AppColors.accentBlue,
            fontSize: 16,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          suffixIcon: isOptional
              ? Icon(Icons.info_outline,
                  color: AppColors.tertiaryText, size: 18)
              : null,
        ),
      ),
    );
  }

  // Custom date picker widget
  Widget _buildDatePicker() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.accentBlue.withOpacity(0.3), width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Text(
          _dueDate == null
              ? "Due Date"
              : "Due Date: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}",
          style: TextStyle(
            color: _dueDate == null
                ? AppColors.secondaryText
                : AppColors.primaryText,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.calendar_today_outlined,
          color: AppColors.accentBlue,
          size: 20,
        ),
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _dueDate ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2101),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.accentBlue,
                    onPrimary: Colors.white,
                    surface: AppColors.cardColor,
                    onSurface: AppColors.primaryText,
                  ),
                  dialogBackgroundColor: AppColors.background,
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() => _dueDate = picked);
          }
        },
      ),
    );
  }

  // Custom file selector widget
  Widget _buildFileSelector({
    required String label,
    required PlatformFile? file,
    required Function() onPickFile,
    IconData icon = Icons.file_present_outlined,
    bool isOptional = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.accentBlue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentBlue, size: 18),
              SizedBox(width: 8),
              Text(
                label + (isOptional ? " (Optional)" : ""),
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          file != null
              ? Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.accentGreen, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          style: TextStyle(
                              color: AppColors.primaryText, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  "No file selected",
                  style: TextStyle(color: AppColors.tertiaryText, fontSize: 14),
                ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPickFile,
            icon: Icon(Icons.upload_file, size: 16),
            label: Text("Select File"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentBlue,
              side: BorderSide(color: AppColors.accentBlue.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
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
            "Create Assignment",
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with gradient background
                Container(
                  margin: EdgeInsets.only(bottom: 20),
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
                          Icons.assignment_outlined,
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
                              "Create Assignment",
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Fill in the details below to create your assignment",
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Form Fields Container
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Assignment Details",
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Styled Text Fields
                      _buildStyledTextField(
                        controller: _titleController,
                        label: "Assignment Title",
                      ),
                      _buildStyledTextField(
                        controller: _descriptionController,
                        label: "Assignment Description",
                        maxLines: 3,
                      ),
                      _buildDatePicker(),
                      _buildFileSelector(
                        label: "Assignment File",
                        file: _pickedFile,
                        onPickFile: pickFile,
                        icon: Icons.file_present_outlined,
                      ),
                      _buildFileSelector(
                        label: "Rubric File",
                        file: _rubricFile,
                        onPickFile: pickRubric,
                        icon: Icons.grading,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Upload Button
                SizedBox(
                  width: double.infinity,
                  child: _isUploading
                      ? Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentBlue,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                "Uploading Assignment...",
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: uploadAssignment,
                          icon: Icon(Icons.cloud_upload_outlined,
                              color: AppColors.background),
                          label: Text(
                            'Upload Assignment',
                            style: TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: AppColors.background,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                        ),
                ),

                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
