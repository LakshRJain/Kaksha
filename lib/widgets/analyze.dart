import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;

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
  // If you didn't initialize in main(), this call is safe (idempotent).
  pdfrxFlutterInitialize();

  final document = await PdfDocument.openFile(pdfFile.path);
  final tempDir = await getTemporaryDirectory();
  final List<String> imagePaths = [];

  try {
    // document.pages is a List<PdfPage>; first page is pages[0]
    for (final page in document.pages) {
      // Choose target pixel dimensions. (page.width / page.height are in points at 72dpi)
      final width = (page.width * 2).toInt();   // ~144 DPI
      final height = (page.height * 2).toInt();

      final pageImage = await page.render(
        width: width,
        height: height,
      );

      if (pageImage == null) continue;

      // createImageNF() returns an `image` package Image
      final imageObj = pageImage.createImageNF();

      // encode to PNG bytes
      final pngBytes = img.encodePng(imageObj);

      final imagePath = '${tempDir.path}/page_${page.pageNumber}.png';
      final file = File(imagePath);
      await file.writeAsBytes(pngBytes);
      imagePaths.add(imagePath);

      // free native resources
      pageImage.dispose();
    }
  } finally {
    // close/dispose document when done
    await document.dispose();
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

    Future<String> firstHalfText =
        _processImageBatch(firstHalf, dotenv.env['API_KEY_1'] ?? '', "API_1");
    Future<String> secondHalfText =
        _processImageBatch(secondHalf, dotenv.env['API_KEY_2'] ?? '', "API_2");

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
    var apiKey = dotenv.env['API_KEY_3'];
    var url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$apiKey';

    String prompt = '''
Assignment Text:
$assignmentText

Rubric Text:
$rubricText

Student Submission Text:
$studentText
Analyze the student's submission based on the assignment text and rubric text. If the final answer is wrong, give step marks.
Full marks for the assignment is in the rubrics.
Be very liberal while giving marks.
Give total marks only along with a short overall feedback of strong or weak topics.
Follow this format:
"Marks"_"Feedback"
Always the output should of this format.
''';

    try {
      print(
          '[GeminiAPI] Using API key: ${apiKey != null ? "Loaded" : "MISSING"}');
      print('[GeminiAPI] Endpoint: $url');
      print('[GeminiAPI] Prompt length: ${prompt.length} chars');

      final body = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      };
      print(
          '[GeminiAPI] Request body: ${jsonEncode(body).substring(0, 300)}...'); // print first 300 chars

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('[GeminiAPI] Response status: ${response.statusCode}');
      print('[GeminiAPI] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null &&
            jsonResponse['candidates'].isNotEmpty) {
          final output =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          print('[GeminiAPI] Parsed output: $output');
          return output;
        } else {
          print('[GeminiAPI] No candidates in response.');
        }
      } else {
        print('[GeminiAPI] Non-200 status. Headers: ${response.headers}');
      }
      return 'Error analyzing submission';
    } catch (e, stacktrace) {
      print('[GeminiAPI] Exception: $e');
      print('[GeminiAPI] Stacktrace: $stacktrace');
      return 'Error: $e';
    }
  }
}
