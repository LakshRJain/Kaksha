import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:open_file/open_file.dart';

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
    const apiKey =
        'AIzaSyCgK2Vlkv-aArK2a0wPusEewhx5WWk-oPU'; // Replace with your Gemini API Key
    const url =
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
          SnackBar(content: Text("Please fill in all required fields!")),
        );
        setState(() => _isLoading = false);
        return;
      }

      String content = await fetchQuestionsFromGemini(
          numQuestions, topic, difficulty, marks, description);

      if (content.isEmpty || content.startsWith("Error")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate questions! Try again.")),
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
      Directory? downloadsDir = Directory("/storage/emulated/0/Download");
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
      String filePath = '${downloadsDir!.path}/QuestionPaper.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF saved in Downloads: $filePath")),
      );

      // Open the generated PDF
      OpenFile.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving PDF: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Generate Question Paper")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _numQuestionsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Number of Questions"),
            ),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(labelText: "Topic"),
            ),
            TextField(
              controller: _difficultyController,
              decoration: InputDecoration(labelText: "Difficulty Level"),
            ),
            TextField(
              controller: _marksController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Marks per Question"),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                  labelText: "Additional Description (Optional)"),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: generateAndSavePdf,
                    child: Text("Generate Question Paper"),
                  ),
          ],
        ),
      ),
    );
  }
}
