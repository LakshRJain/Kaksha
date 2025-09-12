import 'package:flutter/material.dart';

class ImageDisplayScreen extends StatelessWidget {
  final String extractedText;

  const ImageDisplayScreen({super.key, required this.extractedText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Extracted Text'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(extractedText),
      ),
    );
  }
}
