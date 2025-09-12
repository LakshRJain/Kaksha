import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'analyze.dart';

// Define app colors to match the StudentClassDetails style
class AppColors {
  // Base colors
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

class AssignmentDetailScreen extends StatefulWidget {
  final String classId,
      assignmentId,
      title,
      description,
      dueDate,
      fileUrl,
      rubricUrl;

  const AssignmentDetailScreen({
    super.key,
    required this.classId,
    required this.assignmentId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.fileUrl,
    required this.rubricUrl,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final PDFUploadService _pdfService = PDFUploadService();
  final Map<String, bool> _isAnalyzingMap = {};
  bool _isAnalyzingAll = false;
  int _currentAnalyzing = 0, _totalToAnalyze = 0;

  Map<String, String> _formatAnalysisResult(String result) {
    final parts = result.split('_');
    return {
      'marks': parts[0].trim(),
      'feedback': parts.length > 1 ? parts[1].trim() : 'No feedback provided'
    };
  }

  Future<void> _analyzeSubmission(
      String studentFileUrl, String submissionId) async {
    setState(() => _isAnalyzingMap[submissionId] = true);

    try {
      final assignmentText =
          await _pdfService.extractTextFromPDF(widget.fileUrl);
      final rubricText = await _pdfService.extractTextFromPDF(widget.rubricUrl);
      final studentText = await _pdfService.extractTextFromPDF(studentFileUrl);
      final rawResult = await _pdfService.sendToGeminiAPI(
          assignmentText, rubricText, studentText);
      final formattedResult = _formatAnalysisResult(rawResult);

      if (mounted) _showResultDialog(formattedResult, submissionId);
    } catch (e) {
      if (mounted) {
        _showResultDialog(
            {'marks': 'Error', 'feedback': 'Error analyzing submission: $e'},
            submissionId);
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingMap.remove(submissionId));
    }
  }

  Future<void> _analyzeAllSubmissions(
      List<QueryDocumentSnapshot> submissions) async {
    if (_isAnalyzingAll) return;

    setState(() {
      _isAnalyzingAll = true;
      _currentAnalyzing = 0;
      _totalToAnalyze = submissions.length;
    });

    try {
      final assignmentText =
          await _pdfService.extractTextFromPDF(widget.fileUrl);
      final rubricText = await _pdfService.extractTextFromPDF(widget.rubricUrl);
      _showSnackBar('Starting analysis of all submissions...',
          color: AppColors.accentBlue);

      for (int i = 0; i < submissions.length && mounted; i++) {
        final submission = submissions[i];
        final submissionId = submission.id;
        final studentFileUrl = submission['fileUrl'];
        setState(() => _currentAnalyzing = i + 1);

        try {
          final studentText =
              await _pdfService.extractTextFromPDF(studentFileUrl);
          final rawResult = await _pdfService.sendToGeminiAPI(
              assignmentText, rubricText, studentText);
          final formattedResult = _formatAnalysisResult(rawResult);

          await FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.classId)
              .collection('assignments')
              .doc(widget.assignmentId)
              .collection('submissions')
              .doc(submissionId)
              .update({
            'analysisResult': {
              'marks': formattedResult['marks'],
              'feedback': formattedResult['feedback']
            }
          });

          if (mounted) {
            _showSnackBar(
              'Analyzed ${submission['studentName'] ?? 'Unknown'} (${i + 1}/${submissions.length})',
              color: AppColors.accentBlue,
              duration: const Duration(seconds: 1),
            );
          }
        } catch (e) {
          if (mounted) {
            _showSnackBar('Error analyzing submission ${i + 1}: $e',
                color: AppColors.accentRed);
          }
        }
      }

      if (mounted) {
        _showSnackBar('All submissions analyzed and saved',
            color: AppColors.accentGreen);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error during analysis: $e', color: AppColors.accentRed);
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingAll = false);
    }
  }

  void _showSnackBar(String message,
      {required Color color, Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  void _showResultDialog(Map<String, String> result, String submissionId) {
    final marksController = TextEditingController(text: result['marks']);
    final feedbackController = TextEditingController(text: result['feedback']);
    bool isUpdating = false;
    bool isExpandedView = false;
    double fontSize = 15; // Default font size

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.cardColor,
          title: const Text(
            "Analysis Result",
            style: TextStyle(
                color: AppColors.primaryText, fontWeight: FontWeight.w600),
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
                      color: AppColors.surfaceColor,
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
                          style: const TextStyle(
                              color: AppColors.primaryText, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Enter marks',
                            hintStyle:
                                TextStyle(color: AppColors.secondaryText),
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
                            fillColor: AppColors.background,
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
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentBlue.withOpacity(0.5),
                      ),
                    ),
                    height: isExpandedView ? 350 : 150,
                    child: TextField(
                      controller: feedbackController,
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: fontSize),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Enter feedback',
                        hintStyle: TextStyle(color: AppColors.tertiaryText),
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
                  foregroundColor: AppColors.secondaryText),
              child: const Text("Cancel"),
            ),
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  setState(() => isUpdating = true);
                  try {
                    await FirebaseFirestore.instance
                        .collection('classes')
                        .doc(widget.classId)
                        .collection('assignments')
                        .doc(widget.assignmentId)
                        .collection('submissions')
                        .doc(submissionId)
                        .update({
                      'analysisResult': {
                        'marks': marksController.text,
                        'feedback': feedbackController.text
                      }
                    });

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _showSnackBar('Analysis updated successfully',
                          color: AppColors.accentGreen);
                    }
                  } catch (e) {
                    setState(() => isUpdating = false);
                    _showSnackBar('Error updating analysis: $e',
                        color: AppColors.accentRed);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: AppColors.primaryText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Update"),
              ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error opening file.', color: AppColors.accentRed);
      }
    }
  }

  Widget _buildFileDownloadButton(String url, String label) {
    return InkWell(
      onTap: () => _downloadFile(url),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: AppColors.surfaceColor, width: 1))),
        child: Row(
          children: [
            Icon(Icons.description, color: AppColors.accentBlue),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: AppColors.accentBlue, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.download, color: AppColors.accentBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
      QueryDocumentSnapshot submission, String submissionId, bool hasAnalysis) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: hasAnalysis ? AppColors.accentGreen : Colors.transparent,
            width: 1),
      ),
      elevation: 0,
      color: AppColors.cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.accentBlue.withOpacity(0.2),
                      child: Text(
                          (submission['studentName'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(submission['studentName'] ?? 'Unknown',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: AppColors.tertiaryText),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  submission['submittedAt'] != null
                                      ? DateFormat('dd MMM, hh:mm a').format(
                                          (submission['submittedAt']
                                                  as Timestamp)
                                              .toDate())
                                      : 'No submission date',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.tertiaryText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (hasAnalysis)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 14, color: AppColors.accentGreen),
                                  const SizedBox(width: 4),
                                  Text('Analysis available',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.accentGreen)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.file_download,
                            color: AppColors.accentBlue),
                        onPressed: () => _downloadFile(submission['fileUrl']),
                        tooltip: 'Download submission',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isAnalyzingMap[submissionId] == true
                            ? null
                            : () => _analyzeSubmission(
                                submission['fileUrl'], submissionId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasAnalysis
                              ? AppColors.accentGreen
                              : AppColors.accentBlue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isAnalyzingMap[submissionId] == true
                              ? 'Analyzing...'
                              : hasAnalysis
                                  ? 'Analyze'
                                  : 'Analyze',
                          style: TextStyle(
                            color: hasAnalysis
                                ? AppColors.background
                                : AppColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasAnalysis)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: TextButton(
                onPressed: () {
                  final analysisData = submission['analysisResult'];
                  if (analysisData is Map<String, dynamic>) {
                    _showResultDialog({
                      'marks': analysisData['marks'] ?? 'N/A',
                      'feedback':
                          analysisData['feedback'] ?? 'No feedback provided'
                    }, submissionId);
                  } else if (analysisData is String) {
                    _showResultDialog(
                        _formatAnalysisResult(analysisData), submissionId);
                  } else {
                    _showResultDialog({
                      'marks': 'Error',
                      'feedback': 'Invalid analysis format'
                    }, submissionId);
                  }
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.accentBlue,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('View & edit analysis',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
        .format(DateTime.parse(widget.dueDate));

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardColor: AppColors.cardColor,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.accentBlue),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.cardColor,
                  title: const Text("Assignment Info",
                      style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600)),
                  content: Text(widget.description,
                      style: const TextStyle(color: AppColors.secondaryText)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentBlue),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                    color: AppColors.accentBlue.withOpacity(0.3), width: 1),
              ),
              elevation: 0,
              color: AppColors.cardColor,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText)),
                        const SizedBox(height: 12),
                        Text(widget.description,
                            style: const TextStyle(
                                color: AppColors.secondaryText, height: 1.4)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.accentBlue.withOpacity(0.3),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16, color: AppColors.accentBlue),
                              const SizedBox(width: 8),
                              Text("Due: $formattedDate",
                                  style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFileDownloadButton(widget.fileUrl, "View Assignment"),
                  if (widget.rubricUrl.isNotEmpty)
                    _buildFileDownloadButton(widget.rubricUrl, "View Rubric"),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('classes')
                    .doc(widget.classId)
                    .collection('assignments')
                    .doc(widget.assignmentId)
                    .collection('submissions')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentBlue));
                  }

                  final submissions = snapshot.data!.docs;
                  final submissionCount = submissions.length;

                  if (submissionCount == 0) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty,
                              size: 64, color: AppColors.tertiaryText),
                          const SizedBox(height: 16),
                          const Text("No submissions yet",
                              style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.secondaryText)),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Submissions",
                                    style: TextStyle(
                                        color: AppColors.secondaryText,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.assignment_turned_in,
                                        size: 18, color: AppColors.accentBlue),
                                    const SizedBox(width: 8),
                                    Text("$submissionCount",
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryText)),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: _isAnalyzingAll
                                  ? Text(
                                      'Analyzing $_currentAnalyzing/$_totalToAnalyze')
                                  : const Text('Analyze All'),
                              onPressed: _isAnalyzingAll
                                  ? null
                                  : () => _analyzeAllSubmissions(submissions),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _isAnalyzingAll
                                    ? AppColors.surfaceColor
                                    : AppColors.accentBlue,
                                foregroundColor: AppColors.primaryText,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAnalyzingAll)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Processing submissions...',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondaryText)),
                                  Text('$_currentAnalyzing/$_totalToAnalyze',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.accentBlue,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _totalToAnalyze > 0
                                      ? _currentAnalyzing / _totalToAnalyze
                                      : 0,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surfaceColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accentBlue),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: submissionCount,
                          itemBuilder: (context, index) {
                            final submission = submissions[index];
                            final submissionId = submission.id;
                            final hasAnalysis = submission
                                .data()
                                .toString()
                                .contains('analysisResult');
                            return _buildSubmissionCard(
                                submission, submissionId, hasAnalysis);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
