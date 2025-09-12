import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:classcare/face/common/utils/custom_snackbar.dart';
import 'package:classcare/face/common/utils/extract_face_feature.dart';
import 'package:classcare/face/common/views/camera_view.dart';
import 'package:classcare/models/user_model.dart';
import 'package:classcare/screens/student/mark_att.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_face_api/face_api.dart' as regula;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AuthenticateFaceView extends StatefulWidget {
  const AuthenticateFaceView({super.key});

  @override
  State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
}

class _AuthenticateFaceViewState extends State<AuthenticateFaceView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  FaceFeatures? _faceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();

  String _similarity = "";
  List<dynamic> users = [];
  UserModel? loggingUser;
  bool isMatching = false;
  int trialNumber = 1;

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: 'Authenticate Face'
            .gradientText([Colors.blueAccent, Colors.purpleAccent])
            .animate()
            .fadeIn(),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        CameraView(
                          onImage: (image) => _setImage(image),
                          onInputImage: (inputImage) async {
                            setState(() => isMatching = true);
                            _faceFeatures = await extractFaceFeatures(
                                inputImage, _faceDetector);

                            if (_faceFeatures != null) {
                              _fetchUsersAndMatchFace();
                            } else {
                              setState(() => isMatching = false);
                            }
                          },
                        ),
                        if (isMatching)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: Colors.blueAccent),
                                  SizedBox(height: 15),
                                  Text('Authenticating...',
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
            ],
          ),
        ),
      ),
    );
  }

  Future _setImage(Uint8List imageToAuthenticate) async {
    image2.bitmap = base64Encode(imageToAuthenticate);
    image2.imageType = regula.ImageType.PRINTED;
  }

  // 🔹 Simple landmark distance comparison
  double compareFaces(FaceFeatures face1, FaceFeatures face2) {
    double distEar1 = euclideanDistance(face1.rightEar!, face1.leftEar!);
    double distEar2 = euclideanDistance(face2.rightEar!, face2.leftEar!);
    double ratioEar = distEar1 / distEar2;

    double distEye1 = euclideanDistance(face1.rightEye!, face1.leftEye!);
    double distEye2 = euclideanDistance(face2.rightEye!, face2.leftEye!);
    double ratioEye = distEye1 / distEye2;

    double distCheek1 = euclideanDistance(face1.rightCheek!, face1.leftCheek!);
    double distCheek2 = euclideanDistance(face2.rightCheek!, face2.leftCheek!);
    double ratioCheek = distCheek1 / distCheek2;

    double distMouth1 = euclideanDistance(face1.rightMouth!, face1.leftMouth!);
    double distMouth2 = euclideanDistance(face2.rightMouth!, face2.leftMouth!);
    double ratioMouth = distMouth1 / distMouth2;

    double distNoseToMouth1 =
        euclideanDistance(face1.noseBase!, face1.bottomMouth!);
    double distNoseToMouth2 =
        euclideanDistance(face2.noseBase!, face2.bottomMouth!);
    double ratioNoseToMouth = distNoseToMouth1 / distNoseToMouth2;

    return (ratioEye + ratioEar + ratioCheek + ratioMouth + ratioNoseToMouth) /
        5;
  }

  double euclideanDistance(Points p1, Points p2) =>
      math.sqrt(math.pow((p1.x! - p2.x!), 2) + math.pow((p1.y! - p2.y!), 2));

  // 🔹 Fetch users and compare faces
  _fetchUsersAndMatchFace() {
    FirebaseFirestore.instance.collection("face").get().catchError((e) {
      log("Error: $e");
      setState(() => isMatching = false);
      CustomSnackBar.errorSnackBar("Something went wrong. Please try again.");
    }).then((snap) {
      if (snap.docs.isNotEmpty) {
        users.clear();
        for (var doc in snap.docs) {
          UserModel user = UserModel.fromJson(doc.data());
          if (_faceFeatures != null && user.faceFeatures != null) {
            double similarity =
                compareFaces(_faceFeatures!, user.faceFeatures!);
            if (similarity >= 0.8 && similarity <= 1.5) {
              users.add([user, similarity]);
            }
          }
        }
        setState(() => users.sort((a, b) => (((a.last as double) - 1).abs())
            .compareTo(((b.last as double) - 1).abs())));
        _matchFaces();
      } else {
        _showFailureDialog(
          title: "No Users Registered",
          description: "Register users before authenticating.",
        );
      }
    });
  }

  _matchFaces() async {
    bool faceMatched = false;
    for (List user in users) {
      image1.bitmap = (user.first as UserModel).image;
      image1.imageType = regula.ImageType.PRINTED;

      var request = regula.MatchFacesRequest();
      request.images = [image1, image2];
      try {
        dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request));
        var response = regula.MatchFacesResponse.fromJson(json.decode(value));
        dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
            jsonEncode(response!.results), 0.75);
        var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(
            json.decode(str));

        setState(() {
          _similarity = split!.matchedFaces.isNotEmpty
              ? (split.matchedFaces[0]!.similarity! * 100).toStringAsFixed(2)
              : "error";
          if (_similarity != "error" && double.parse(_similarity) > 90.00) {
            faceMatched = true;
            loggingUser = user.first;
          }
        });

        if (faceMatched) {
          if (!mounted) return;
          Navigator.pop(context, true); // ✅ return success
          break;
        }
      } catch (e) {
        log("JSON Parsing Error: $e");
        CustomSnackBar.errorSnackBar(
            "Authentication failed. Please try again.");
        setState(() => isMatching = false);
        return;
      }
    }
    if (!faceMatched) _handleFailedAuthentication();
  }

  _handleFailedAuthentication() {
    setState(() => trialNumber++);
    _showFailureDialog(
      title: "Authentication Failed",
      description: "Face doesn't match. Please try again.",
    );
  }

  _showFailureDialog({required String title, required String description}) {
    setState(() => isMatching = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context, false); // ❌ return fail
            },
            child: const Text("OK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
