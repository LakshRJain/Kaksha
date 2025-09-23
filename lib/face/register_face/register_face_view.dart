import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:classcare/face/common/utils/extensions/size_extension.dart';
import 'package:classcare/face/common/utils/extract_face_feature.dart';
import 'package:classcare/face/common/views/camera_view.dart';
import 'package:classcare/face/common/views/custom_button.dart';
import 'package:classcare/face/register_face/enter_details_view.dart';
import 'package:classcare/models/user_model.dart';
import 'package:classcare/screens/student/mark_att.dart';
import 'package:classcare/screens/teacher/generate_mcq_screen.dart';
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
        title: Text('Face Registration', style: TextStyle(color: Colors.white)),
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
                left: 24,
                right: 24,
              ),
              child: Column(
                children: [
                  // Status indicator
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: (_image != null && _faceFeatures != null)
                          ? AppColors.accentGreen.withOpacity(0.1)
                          : AppColors.accentYellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_image != null && _faceFeatures != null)
                            ? AppColors.accentGreen.withOpacity(0.3)
                            : AppColors.accentYellow.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (_image != null && _faceFeatures != null)
                                ? AppColors.accentGreen.withOpacity(0.2)
                                : AppColors.accentYellow.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (_image != null && _faceFeatures != null)
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: (_image != null && _faceFeatures != null)
                                ? AppColors.accentGreen
                                : AppColors.accentYellow,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (_image != null && _faceFeatures != null)
                                ? 'Face captured and processed successfully!'
                                : 'Please capture your face to continue',
                            style: TextStyle(
                              color: (_image != null && _faceFeatures != null)
                                  ? AppColors.accentGreen
                                  : AppColors.accentYellow,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeInUp(delay: 300.ms, duration: 500.ms),

                  // Complete button
                  GestureDetector(
                    onTap: (_image != null && _faceFeatures != null)
                        ? () {
                            // Add haptic feedback
                            // HapticFeedback.mediumImpact();

                            Navigator.pop(context, {
                              'image': _image!,
                              'faceFeatures': _faceFeatures!,
                            });
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: (_image != null && _faceFeatures != null)
                            ? LinearGradient(
                                colors: [
                                  AppColors.accentBlue,
                                  AppColors.accentBlue.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  AppColors.surfaceColor,
                                  AppColors.surfaceColor.withOpacity(0.8),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (_image != null && _faceFeatures != null)
                              ? AppColors.accentBlue.withOpacity(0.3)
                              : AppColors.surfaceColor,
                          width: 1,
                        ),
                        boxShadow: (_image != null && _faceFeatures != null)
                            ? [
                                BoxShadow(
                                  color: AppColors.accentBlue.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: Stack(
                        children: [
                          // Shimmer effect when enabled
                          if (_image != null && _faceFeatures != null)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.1),
                                      Colors.white.withOpacity(0.2),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),

                          // Button content
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (_image != null &&
                                            _faceFeatures != null)
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    (_image != null && _faceFeatures != null)
                                        ? Icons.check_circle
                                        : Icons.face_retouching_natural,
                                    color: (_image != null &&
                                            _faceFeatures != null)
                                        ? Colors.white
                                        : AppColors.secondaryText,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    color: (_image != null &&
                                            _faceFeatures != null)
                                        ? Colors.white
                                        : AppColors.secondaryText,
                                    fontSize: 16,
                                    fontWeight: (_image != null &&
                                            _faceFeatures != null)
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  child: Text(
                                    (_image != null && _faceFeatures != null)
                                        ? 'Complete Registration'
                                        : 'Complete',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeInUp(delay: 400.ms, duration: 600.ms)
                      .animate(
                        target:
                            (_image != null && _faceFeatures != null) ? 1 : 0,
                      )
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.02, 1.02),
                        duration: 200.ms,
                      ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
