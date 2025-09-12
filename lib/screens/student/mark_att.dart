import 'dart:ui';
import 'package:classcare/face/authenticate_face/authenticate_face_view.dart';
import 'package:classcare/face/common/utils/custom_snackbar.dart';
import 'package:classcare/face/common/utils/screen_size_util.dart';
import 'package:classcare/face/register_face/register_face_view.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Face extends StatefulWidget {
  const Face({super.key});

  @override
  _FaceState createState() => _FaceState();
}

class _FaceState extends State<Face> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isUserRegistered = false;
  bool isAttendanceMarked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      checkIfUserIsRegistered(),
      checkIfAttendanceMarked(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> checkIfUserIsRegistered() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('face')
          .doc(currentUser.uid)
          .get();
      if (mounted) {
        setState(() => isUserRegistered = doc.exists);
      }
    }
  }

  Future<void> checkIfAttendanceMarked() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('email', isEqualTo: currentUser.email)
            .where('date', isEqualTo: _getFormattedDate(DateTime.now()))
            .get();
        if (mounted) {
          setState(() => isAttendanceMarked = snapshot.docs.isNotEmpty);
        }
      } catch (e) {
        print('Error checking attendance: $e');
      }
    }
  }

  String _getFormattedDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void initializeUtilContexts(BuildContext context) {
    ScreenSizeUtil.context = context;
    CustomSnackBar.context = context;
  }

  @override
  Widget build(BuildContext context) {
    initializeUtilContexts(context);

    return Scaffold(
      key: _scaffoldKey,
      // drawer: const UserProfileDrawer(),
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
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.blueAccent),
                    )
                  : SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildIllustration(),
                              const SizedBox(height: 40),
                              if (!isUserRegistered) _buildRegisterButton(),
                              if (!isUserRegistered) const SizedBox(height: 20),
                              _buildMarkAttendanceButton(),
                              const SizedBox(height: 30),
                              if (isAttendanceMarked) _buildAttendanceStatus(),
                            ],
                          ).animate().fadeIn(delay: 200.ms),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: 'Face Attendance'
          .gradientText([Colors.blueAccent, Colors.purpleAccent])
          .animate()
          .fadeIn(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildIllustration() {
    return Image.asset('assets/Checklist Background Removed.png')
        .animate()
        .scale(delay: 300.ms)
        .fadeIn();
  }

  Widget _buildRegisterButton() {
    return Animate(
      effects: const [SlideEffect()],
      child: CardButton(
        text: "Register Face",
        icon: Icons.face_retouching_natural,
        onTap: () {
          Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RegisterFaceView()))
              .then((_) => checkIfUserIsRegistered());
        },
      ),
    );
  }

  Widget _buildMarkAttendanceButton() {
    return Animate(
      effects: const [SlideEffect()],
      child: CardButton(
        text: "Mark Attendance",
        icon: Icons.fingerprint,
        onTap: () {
          Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AuthenticateFaceView()))
              .then((result) => _handleAttendanceResult(result));
        },
      ),
    );
  }

  void _handleAttendanceResult(String? result) {
    if (result == 'success') {
      setState(() => isAttendanceMarked = true);
      _showAttendanceDialog(
          "Attendance Marked!",
          "Successfully marked attendance for today",
          Icons.check_circle,
          Colors.green);
    } else if (result == 'already_marked') {
      _showAttendanceDialog("Already Marked",
          "Attendance already recorded for today", Icons.info, Colors.amber);
    }
  }

  void _showAttendanceDialog(
      String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 20),
              Text(title,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 10),
              Text(content,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('OK', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceStatus() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withOpacity(0.2),
              Colors.green.withOpacity(0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.greenAccent.withOpacity(0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Attendance marked for today!",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ]));
  }
}

class CardButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const CardButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 15),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension TextExtension on String {
  Widget get textWhite => Text(
        this,
        style: const TextStyle(color: Colors.white),
      );

  Widget gradientText(List<Color> colors) => ShaderMask(
        shaderCallback: (bounds) =>
            LinearGradient(colors: colors).createShader(bounds),
        child: Text(
          this,
          style: const TextStyle(color: Colors.white),
        ),
      );
}

extension TextWidgetExtension on Widget {
  Widget makeWithGradient(Gradient gradient) => ShaderMask(
        shaderCallback: (bounds) => gradient.createShader(bounds),
        child: this,
      );
}
