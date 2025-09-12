import 'package:classcare/face/common/utils/extensions/size_extension.dart';
import 'package:classcare/face/theme.dart';
import 'package:classcare/models/user_model.dart';
import 'package:classcare/screens/student/mark_att.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserDetailsView extends StatelessWidget {
  final UserModel user;
  const UserDetailsView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: 'Authentication Success'
            .gradientText([Colors.blueAccent, Colors.purpleAccent]),
        iconTheme: const IconThemeData(color: primaryWhite),
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
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -0.2.sw,
              top: -0.1.sh,
              child: Container(
                width: 0.5.sw,
                height: 0.5.sw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withOpacity(0.2),
                          Colors.purpleAccent.withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        ),
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: accentColor,
                          child: Icon(
                            Icons.face_retouching_natural,
                            size: 40,
                            color: primaryWhite,
                          ),
                        )
                            .animate()
                            .scale(delay: 300.ms, duration: 500.ms)
                            .then()
                            .shake(),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
                  SizedBox(height: 0.04.sh),
                  Text(
                    user.name ?? 'Guest User', // Handle null name
                    style: TextStyle(
                      fontSize: 0.03.sh,
                      fontWeight: FontWeight.w700,
                      color: primaryWhite,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 0.04.sh),
                  Container(
                    width: 0.7.sw,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withOpacity(0.1),
                          Colors.purpleAccent.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Authentication Successful!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 0.022.sh,
                            fontWeight: FontWeight.w600,
                            color: Colors.greenAccent,
                          ),
                        ),
                        SizedBox(height: 0.01.sh),
                        Text(
                          'User verified through facial recognition',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 0.016.sh,
                            color: primaryWhite.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 0.05.sh),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(
                        horizontal: 0.1.sw,
                        vertical: 0.02.sh,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const StudentNav(),
                      //   ),
                      // );
                    },
                    child: Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 0.018.sh,
                        color: primaryWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
