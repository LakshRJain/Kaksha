import 'dart:convert';
import 'package:classcare/face/common/utils/extensions/size_extension.dart';
import 'package:classcare/face/common/utils/extract_face_feature.dart';
import 'package:classcare/face/common/views/camera_view.dart';
import 'package:classcare/face/common/views/custom_button.dart';
import 'package:classcare/face/register_face/enter_details_view.dart';
import 'package:classcare/models/user_model.dart';
import 'package:classcare/screens/student/mark_att.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class RegisterFaceView extends StatefulWidget {
  const RegisterFaceView({super.key});

  @override
  State<RegisterFaceView> createState() => _RegisterFaceViewState();
}

class _RegisterFaceViewState extends State<RegisterFaceView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  String? _image;
  FaceFeatures? _faceFeatures;
  bool _isProcessing = false;

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: 'Face Registration'
            .gradientText([Colors.blueAccent, Colors.purpleAccent])
            .animate()
            .fadeIn(),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F0F),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
            stops: [0.1, 0.5, 0.9],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight),
            Expanded(
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        CameraView(
                          onImage: (image) {
                            setState(() {
                              _image = base64Encode(image);
                            });
                          },
                          onInputImage: (inputImage) async {
                            setState(() => _isProcessing = true);
                            _faceFeatures = await extractFaceFeatures(
                                inputImage, _faceDetector);
                            setState(() => _isProcessing = false);
                          },
                        ),
                        if (_isProcessing)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  ),
                                  SizedBox(height: 15),
                                  Text('Analyzing Face Features...',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.05,
                top: 20,
              ),
              child: Animate(
                effects: const [SlideEffect()],
                child: CustomButton(
                  text: "Complete",
                  icon: Icons.face_retouching_natural,
                  onTap: (_image != null && _faceFeatures != null)
                      ? () {
                          Navigator.pop(context, {
                            'image': _image!,
                            'faceFeatures': _faceFeatures!,
                          });
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
