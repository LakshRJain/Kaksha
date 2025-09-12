import 'package:classcare/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipe_button/flutter_swipe_button.dart';
import 'package:lottie/lottie.dart';
class Start extends StatelessWidget {
  const Start({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 2, 3, 3),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App Icon
              SizedBox(
                      height: 200, // Adjust height as needed
                      child: Lottie.asset(
                        'assets/front.json', // Ensure this file is present in assets
                        fit: BoxFit.contain,
                      ),
                    ),

              const SizedBox(height: 10),

              // Welcome Text
              const Text(
                "WELCOME TO",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.teal,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                "KAKSHA",
                style: TextStyle(
                  fontFamily: 'Ariel',
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(38, 166, 154, 1),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 1),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  "Smart Assistant for Smarter Teaching",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 80),

              // Get Started Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    const Text(
                      "Get started as",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Swipe Button for Teacher with Shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 224, 238, 237)
                                .withOpacity(0.4),
                            spreadRadius: 3,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SwipeButton.expand(
                        thumb: const Icon(
                          Icons.double_arrow_rounded,
                          color: Colors.white,
                        ),
                        activeThumbColor:
                            const Color.fromARGB(255, 109, 180, 173),
                        activeTrackColor: Colors.grey.shade300,
                        onSwipe: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) =>
                                  LoginPage(post: "Teacher"),
                            ),
                          );
                        },
                        child: const Text(
                          "Teacher",
                          style: TextStyle(
                            fontSize: 20,
                            color: Color.fromARGB(255, 1, 138, 124),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Swipe Button for Student with Shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 227, 217, 217)
                                .withOpacity(0.4),
                            spreadRadius: 3,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SwipeButton.expand(
                        thumb: const Icon(
                          Icons.double_arrow_rounded,
                          color: Colors.white,
                        ),
                        activeThumbColor:
                            const Color.fromARGB(255, 246, 182, 182),
                        activeTrackColor: Colors.grey.shade300,
                        onSwipe: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) =>
                                  LoginPage(post: "Student"),
                            ),
                          );
                        },
                        child: const Text(
                          "Student",
                          style: TextStyle(
                            fontSize: 20,
                            color: Color.fromARGB(255, 232, 117, 117),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}