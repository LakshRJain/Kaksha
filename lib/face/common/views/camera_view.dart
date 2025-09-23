import 'dart:io';
import 'dart:typed_data';

import 'package:classcare/face/common/utils/extensions/size_extension.dart';
import 'package:classcare/face/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class CameraView extends StatefulWidget {
  const CameraView(
      {super.key, required this.onImage, required this.onInputImage});

  final Function(Uint8List image) onImage;
  final Function(InputImage inputImage) onInputImage;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with TickerProviderStateMixin {
  File? _image;
  ImagePicker? _imagePicker;
  AnimationController? _pulseController;
  AnimationController? _captureController;
  Animation<double>? _pulseAnimation;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();

    // Pulse animation for capture button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    _pulseController!.repeat(reverse: true);

    // Scale animation for capture feedback
    _captureController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _captureController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _captureController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Main content area
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Face preview container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _image != null
                            ? Colors.green.withOpacity(0.8)
                            : primaryWhite.withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_image != null ? Colors.green : primaryWhite)
                              .withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _image != null
                          ? CircleAvatar(
                              key: ValueKey(_image.hashCode),
                              radius: screenHeight * 0.12,
                              backgroundImage: FileImage(_image!),
                            )
                          : CircleAvatar(
                              key: const ValueKey('placeholder'),
                              radius: screenHeight * 0.12,
                              backgroundColor: primaryWhite.withOpacity(0.1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.face_retouching_natural,
                                    size: screenHeight * 0.06,
                                    color: primaryWhite.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Position Face',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryWhite.withOpacity(0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _image != null
                          ? 'Face captured successfully!'
                          : 'Tap the button to capture your face',
                      key: ValueKey(_image != null),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: _image != null
                            ? Colors.green.withOpacity(0.9)
                            : primaryWhite.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom section with capture button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                // Capture button
                AnimatedBuilder(
                  animation:
                      _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    return AnimatedBuilder(
                      animation:
                          _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
                      builder: (context, child) {
                        final pulseValue = _pulseAnimation?.value ?? 1.0;
                        final scaleValue = _scaleAnimation?.value ?? 1.0;

                        return Transform.scale(
                          scale:
                              scaleValue * (_image == null ? pulseValue : 1.0),
                          child: GestureDetector(
                            onTapDown: (_) => _captureController?.forward(),
                            onTapUp: (_) {
                              _captureController?.reverse();
                              _getImage();
                            },
                            onTapCancel: () => _captureController?.reverse(),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _image != null
                                    ? LinearGradient(
                                        colors: [
                                          Colors.green.withOpacity(0.8),
                                          Colors.green.withOpacity(0.6),
                                        ],
                                      )
                                    : RadialGradient(
                                        stops: const [0.3, 0.7, 1],
                                        colors: [
                                          primaryWhite,
                                          primaryWhite.withOpacity(0.9),
                                          primaryWhite.withOpacity(0.7),
                                        ],
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_image != null
                                            ? Colors.green
                                            : primaryWhite)
                                        .withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _image != null
                                    ? Icons.check_circle_outline
                                    : Icons.camera_alt,
                                size: 35,
                                color: _image != null
                                    ? Colors.white
                                    : const Color(0xff2E2E2E),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Action text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _image != null ? 'Tap to capture again' : 'Tap to capture',
                    key: ValueKey(_image != null ? 'retake' : 'capture'),
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryWhite.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // Retake option
                if (_image != null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _image = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: primaryWhite.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryWhite.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: primaryWhite.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Clear & Retake',
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryWhite.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future _getImage() async {
    // Add haptic feedback
    // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback

    final pickedFile = await _imagePicker?.pickImage(
      source: ImageSource.camera,
      maxWidth: 400,
      maxHeight: 400,
      preferredCameraDevice:
          CameraDevice.front, // Use front camera for face capture
    );

    if (pickedFile != null) {
      _setPickedFile(pickedFile);
    }
  }

  Future _setPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) {
      return;
    }

    setState(() {
      _image = File(path);
    });

    Uint8List imageBytes = _image!.readAsBytesSync();
    widget.onImage(imageBytes);

    InputImage inputImage = InputImage.fromFilePath(path);
    widget.onInputImage(inputImage);
  }
}
