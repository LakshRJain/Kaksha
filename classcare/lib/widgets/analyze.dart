import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';

class PDFUploadService {
  Future<String> extractTextFromPDF(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/downloaded_file.pdf';

        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        List<String> imagePaths = await _convertPdfToImages(file);
        print("Generated Image Paths: $imagePaths");

        String extractedText = await extractTextFromImages(imagePaths);
        print("HEREEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE");
        print(extractedText);
        return extractedText;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error extracting text from PDF: $e');
    }
  }

  Future<List<String>> _convertPdfToImages(File pdfFile) async {
    final pdfDocument = await PdfDocument.openFile(pdfFile.path);
    final tempDir = await getTemporaryDirectory();
    List<String> imagePaths = [];

    for (int i = 1; i <= pdfDocument.pageCount; i++) {
      final page = await pdfDocument.getPage(i);
      final pdfPageImage = await page.render(
        width: (page.width * 2).toInt(),
        height: (page.height * 2).toInt(),
      );

      final image = await pdfPageImage.createImageIfNotAvailable();
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final imagePath = '${tempDir.path}/page_$i.png';
      final file = File(imagePath);
      await file.writeAsBytes(buffer);
      imagePaths.add(imagePath);

      image.dispose();
    }
    return imagePaths;
  }

  Future<String> extractTextFromImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return "";

    int totalImages = imagePaths.length;
    int half = (totalImages / 2).ceil();
    List<String> firstHalf = imagePaths.sublist(0, half);
    List<String> secondHalf = imagePaths.sublist(half);

    //print("First Half Images: $firstHalf");
    //print("Second Half Images: $secondHalf");

    Future<String> firstHalfText = _processImageBatch(
        firstHalf, "AIzaSyAiH173s0PPDFWNtJpcuzPLdu3i_0mi8Ao", "API_1");
    Future<String> secondHalfText = _processImageBatch(
        secondHalf, "AIzaSyB4mpffbJQfgCzdBX_z6dELHqSRI0hvg_I", "API_2");

    List<String> results = await Future.wait([firstHalfText, secondHalfText]);

    //print("Extracted First Half Text: ${results[0]}");
    //print("Extracted Second Half Text: ${results[1]}");

    return results.join();
  }

  Future<String> _processImageBatch(
      List<String> imagePaths, String apiKey, String apiLabel) async {
    String extractedText = "";

    //print("Processing $apiLabel with images: $imagePaths");

    for (String imagePath in imagePaths) {
      File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        print("Error: Image $imagePath does not exist.");
        continue;
      }

      //print("Processing image: $imagePath with $apiLabel");

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(
            'https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "requests": [
            {
              "image": {"content": base64Image},
              "features": [
                {"type": "DOCUMENT_TEXT_DETECTION"}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody["responses"] != null &&
            responseBody["responses"].isNotEmpty) {
          String text =
              responseBody["responses"][0]["fullTextAnnotation"]["text"] ?? "";
          print("Extracted text from $imagePath: $text");
          extractedText += "$text\n";
        } else {
          print("No text found in $imagePath");
        }
      } else {
        print("Error ${response.statusCode} for $imagePath: ${response.body}");
      }
    }

    //print("Final extracted text for $apiLabel: $extractedText");
    return extractedText;
  }

  Future<String> sendToGeminiAPI(
      String assignmentText, String rubricText, String studentText) async {
    const apiKey = 'AIzaSyDONNPmqMxTQ2gHdUvRdgAZPNKz_1c1YpQ';
    const url =
        'https://generativelanguage.googleapis.com/v1beta/tunedModels/copy-of-analysis-model-pq5mo65ip7q1:generateContent?key=$apiKey';

    String prompt = '''
    Assignment Text:
    $assignmentText

    Rubric Text:
    $rubricText

    Student Submission Text:
    $studentText
    Act as if you are a teacher, who needs to analyse student's assignments. 
    Analyze the student's submission based on the assignment text and rubric text.
    Full marks for the assignment is in the rubrics text.
    Be very lenient while giving marks. Never give marks less than 75% of total marks.
    Give total marks only, along with a short overall feedback of strong or weak topics.
    Follow this format:
    "Marks"_"Feedback"
    Always the output should of this format.
    ''';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null &&
            jsonResponse['candidates'].isNotEmpty) {
          print(jsonResponse);
          return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        }
      }
      return 'Error analyzing submission';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
