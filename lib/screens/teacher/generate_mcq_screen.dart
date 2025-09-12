import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:open_file/open_file.dart';

// Reusing the AppColors class from ClassDetailPage
class AppColors {
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

class GenerateMCQScreen extends StatefulWidget {
  const GenerateMCQScreen({super.key});

  @override
  _GenerateMCQScreenState createState() => _GenerateMCQScreenState();
}

class _GenerateMCQScreenState extends State<GenerateMCQScreen> {
  final TextEditingController _numQuestionsController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _difficultyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _numQuestionsController.dispose();
    _topicController.dispose();
    _difficultyController.dispose();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<String> fetchMCQsFromGemini(
      int numQuestions, String topic, String difficulty) async {
    var apiKey = dotenv.env['API_KEY_5'] ?? '';
    var url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    String prompt = """
      Generate strictly $numQuestions multiple-choice questions on the topic '$topic' with difficulty level '$difficulty'.
      Each question should have four options labeled 0, 1, 2, and 3, with one correct answer.
      Try to make length of the questions and options to be small.
      Return the output in a structured CSV format:
      Question,Option 0,Option 1,Option 2,Option 3,Answer
      Ensure that:
      - Each field is separated by a comma.
      - There are no extra line breaks inside a field.
      - Use double quotes to enclose any field containing a comma.
    """;

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
                  .join("\n");
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

  Future<void> generateAndSaveCSV() async {
    setState(() => _isLoading = true);
    try {
      await requestPermissions();
      int numQuestions = int.tryParse(_numQuestionsController.text) ?? 0;
      String topic = _topicController.text.trim();
      String difficulty = _difficultyController.text.trim();

      if (numQuestions <= 0 || topic.isEmpty || difficulty.isEmpty) {
        _showSnackBar('Please enter valid details!', AppColors.accentYellow);
        setState(() => _isLoading = false);
        return;
      }

      String content =
          await fetchMCQsFromGemini(numQuestions, topic, difficulty);
      if (content.isEmpty || content.startsWith("Error")) {
        _showSnackBar(
            'Failed to generate content! Try again.', AppColors.accentRed);
        setState(() => _isLoading = false);
        return;
      }

      List<String> lines =
          content.split("\n").where((line) => line.trim().isNotEmpty).toList();
      List<List<String>> mcqData = [];

      for (var line in lines) {
        List<String> values = line.split(",");
        if (values.length == 6) {
          mcqData.add(values.map((e) => e.trim()).toList());
        }
      }

      if (mcqData.isEmpty) {
        _showSnackBar('Generated data is not in the correct format!',
            AppColors.accentRed);
        setState(() => _isLoading = false);
        return;
      }

      List<String> csvData = [];
      for (var mcq in mcqData) {
        csvData.add(mcq.map((e) => '"$e"').join(","));
      }

      Directory? downloadsDir = Directory("/storage/emulated/0/Download");
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
      String filePath = '${downloadsDir!.path}/MCQ_$topic.csv';
      final file = File(filePath);
      await file.writeAsString(csvData.join("\n"));

      _showSnackBar('CSV saved in Downloads: $filePath', AppColors.accentGreen);
      OpenFile.open(filePath);
    } catch (e) {
      _showSnackBar('Error saving CSV: $e', AppColors.accentRed);
    } finally {
      setState(() => _isLoading = false);
    }
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required Color color,
    int maxLines = 1,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: AppColors.primaryText,
          fontSize: 14,
        ),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: color, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            'Generate MCQs',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section similar to ClassDetailPage
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
                            "MCQ Generator",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Create and export multiple choice questions",
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

                // Content Card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(w * 0.03),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Question Parameters",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Number of Questions Input
                      _buildTextField(
                        controller: _numQuestionsController,
                        labelText: 'Number of Questions',
                        icon: Icons.numbers,
                        color: AppColors.accentBlue,
                      ),

                      // Topic Input
                      _buildTextField(
                        controller: _topicController,
                        labelText: 'Topic',
                        icon: Icons.topic,
                        color: AppColors.accentGreen,
                      ),

                      // Difficulty Input
                      _buildTextField(
                        controller: _difficultyController,
                        labelText: 'Difficulty Level',
                        icon: Icons.auto_graph,
                        color: AppColors.accentPurple,
                      ),

                      SizedBox(height: 24),

                      // Generate Button
                      Center(
                        child: _isLoading
                            ? CircularProgressIndicator(
                                color: AppColors.accentBlue,
                              )
                            : Container(
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
                                      color:
                                          AppColors.accentBlue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: generateAndSaveCSV,
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
                                      Icon(
                                        Icons.generating_tokens,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Generate CSV',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
