import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:open_file/open_file.dart';

class GeneratePdfScreen extends StatefulWidget {
  const GeneratePdfScreen({super.key});

  @override
  _GeneratePdfScreenState createState() => _GeneratePdfScreenState();
}

class _GeneratePdfScreenState extends State<GeneratePdfScreen> {
  final TextEditingController _topicController = TextEditingController();
  bool _isLoading = false;

  /// Request Storage Permissions
  Future<void> requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  /// Fetch Content from Gemini API
  Future<String> fetchContentFromGemini(String topic) async {
    const apiKey =
        'AIzaSyCgK2Vlkv-aArK2a0wPusEewhx5WWk-oPU'; // Replace with your Gemini API Key
    const url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    String prompt =
        "Generate a well-structured, detailed document about \"$topic\" with insights, examples, and key information. It should be enough to fill atleast 25 slides.";

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

  /// Generate and Save PDF
  Future<void> generateAndSavePdf(String topic) async {
    setState(() => _isLoading = true);

    try {
      await requestPermissions();
      String content = await fetchContentFromGemini(topic);

      if (content.isEmpty || content.startsWith("Error")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate content! Try again.")),
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
                topic,
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: content
                    .split("\n\n") // Split content into paragraphs
                    .map((para) => pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 8),
                          child: pw.Text(
                            para,
                            style: pw.TextStyle(fontSize: 14),
                            textAlign: pw.TextAlign.justify,
                          ),
                        ))
                    .toList(),
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
      String filePath = '${downloadsDir!.path}/$topic.pdf';
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
      appBar: AppBar(title: Text("Generate PDF")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _topicController,
              decoration: InputDecoration(labelText: "Enter Topic"),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      String topic = _topicController.text.trim();
                      if (topic.isNotEmpty) {
                        generateAndSavePdf(topic);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please enter a topic!")),
                        );
                      }
                    },
                    child: Text("Generate PDF"),
                  ),
          ],
        ),
      ),
    );
  }
}
