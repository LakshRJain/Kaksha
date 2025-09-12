import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:classcare/widgets/Colors.dart';

class GenerateQuestionPaperScreen extends StatefulWidget {
  const GenerateQuestionPaperScreen({super.key});

  @override
  _GenerateQuestionPaperScreenState createState() =>
      _GenerateQuestionPaperScreenState();
}

class _GenerateQuestionPaperScreenState
    extends State<GenerateQuestionPaperScreen> {
  final TextEditingController _numQuestionsController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _difficultyController = TextEditingController();
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  /// Request Storage Permissions
  Future<void> requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  /// Fetch Questions from Gemini API
  Future<String> fetchQuestionsFromGemini(int numQuestions, String topic,
      String difficulty, String marks, String description) async {
    var apiKey =
        dotenv.env['API_KEY_3'] ?? ''; // Replace with your Gemini API Key
    var url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    String prompt =
        "Generate $numQuestions well-structured exam questions on the topic '$topic'. "
        "Each question should be of '$difficulty' difficulty level and carry '$marks' marks. "
        "${description.isNotEmpty ? "Additional description: $description." : ""} "
        "Provide questions in a numbered format.";

    final requestPayload = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestPayload),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse.containsKey('candidates') &&
            jsonResponse['candidates'].isNotEmpty) {
          var firstCandidate = jsonResponse['candidates'][0];

          if (firstCandidate.containsKey('content')) {
            var content = firstCandidate['content'];

            if (content.containsKey('parts') && content['parts'].isNotEmpty) {
              return content['parts']
                  .map<String>((part) => part['text'].toString())
                  .join("\n\n");
            }
          }
        }
        return 'No valid content found in API response.';
      } else {
        return 'Error: ${response.statusCode}, Response: ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Generate and Save Question Paper PDF
  Future<void> generateAndSavePdf() async {
    setState(() => _isLoading = true);

    try {
      await requestPermissions();
      int numQuestions = int.tryParse(_numQuestionsController.text.trim()) ?? 0;
      String topic = _topicController.text.trim();
      String difficulty = _difficultyController.text.trim();
      String marks = _marksController.text.trim();
      String description = _descriptionController.text.trim();

      if (numQuestions <= 0 ||
          topic.isEmpty ||
          difficulty.isEmpty ||
          marks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please fill in all required fields!"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: AppColors.accentRed.withOpacity(0.8),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      String content = await fetchQuestionsFromGemini(
          numQuestions, topic, difficulty, marks, description);

      if (content.isEmpty || content.startsWith("Error")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to generate questions! Try again."),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: AppColors.accentRed.withOpacity(0.8),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Create PDF document
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return [
              pw.Text(
                "Question Paper",
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Topic: $topic\nDifficulty: $difficulty\nMarks per Question: $marks",
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.ListView.builder(
                itemCount: content.split("\n\n").length,
                itemBuilder: (context, index) {
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      "${index + 1}. ${content.split("\n\n")[index]}",
                      style: pw.TextStyle(fontSize: 14),
                      textAlign: pw.TextAlign.justify,
                    ),
                  );
                },
              ),
            ];
          },
        ),
      );

      // Save PDF in Downloads folder
      Directory? downloadsDir = await getApplicationDocumentsDirectory();
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
      String filePath = '${downloadsDir!.path}/QuestionPaper.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved in Downloads: $filePath'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.accentGreen.withOpacity(0.8),
          duration: Duration(seconds: 2),
        ),
      );

      // Open the generated PDF
      OpenFile.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving PDF: $e"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.accentRed.withOpacity(0.8),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Custom styled text field matching the design
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
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
            "Generate Question Paper",
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
                          Icons.file_present_outlined,
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
                              "Question Paper Generator",
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Fill in the details below to generate your custom question paper",
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 12,
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
                        "Paper Details",
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Styled Text Fields
                      _buildStyledTextField(
                        controller: _numQuestionsController,
                        label: "Number of Questions",
                        keyboardType: TextInputType.number,
                      ),
                      _buildStyledTextField(
                        controller: _topicController,
                        label: "Topic",
                      ),
                      _buildStyledTextField(
                        controller: _difficultyController,
                        label: "Difficulty Level",
                      ),
                      _buildStyledTextField(
                        controller: _marksController,
                        label: "Marks per Question",
                        keyboardType: TextInputType.number,
                      ),
                      _buildStyledTextField(
                        controller: _descriptionController,
                        label: "Additional Description",
                        isOptional: true,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
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
                                "Generating Question Paper...",
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: generateAndSavePdf,
                          icon: Icon(Icons.create_new_folder_outlined,
                              color: AppColors.background),
                          label: Text(
                            'Generate Question Paper',
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

                // Tip Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentYellow.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.accentYellow,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Tip: For the best results, provide a specific topic and clear difficulty level.",
                          style: TextStyle(
                            color: AppColors.accentYellow,
                            fontSize: 14,
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
      ),
    );
  }
}
