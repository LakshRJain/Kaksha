import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classcare/screens/teacher/homeTeacher.dart';
import 'package:classcare/screens/student/hometStudent.dart';
import 'package:classcare/screens/signup.dart';
import 'package:lottie/lottie.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.post});
  final String post;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;

      // Check if email is verified
      if (user != null && !user.emailVerified) {
        setState(() {
          _errorMessage =
              "Please verify your email before logging in. Check your inbox.";
        });
        await FirebaseAuth.instance.signOut(); // Sign out unverified user
        return;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();
      if (userDoc.exists) {
        String? role = userDoc.data()?['role'];
        if (role == widget.post) {
          if (role == 'Teacher') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => TeacherDashboard()),
              (Route<dynamic> route) => false, // Removes all previous routes
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => homeStudent()),
              (Route<dynamic> route) => false, // Removes all previous routes
            );
          }

          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Login successful')));
        } else {
          setState(() {
            _errorMessage = "Access denied: You are not a $role.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "User data not found. Please contact support.";
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = "No account found with this email. Please sign up.";
        } else if (e.code == 'wrong-password') {
          _errorMessage = "Incorrect password. Please try again.";
        } else if (e.code == 'invalid-email') {
          _errorMessage = "Invalid email format. Please check and try again.";
        } else {
          _errorMessage = "An error occurred. Please try again.";
        }
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 5, 4, 5), // Background color
      resizeToAvoidBottomInset:
          false, // Prevents UI shifting when keyboard opens
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              // Used Center to ensure everything stays in place
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    _loginText(),
                    const SizedBox(height: 50),
                    _emailField(),
                    const SizedBox(height: 15),
                    _passwordField(),
                    const SizedBox(height: 15),

                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 118, 211, 214),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],

                    // 🔥 LOTTIE ANIMATION 🔥
                    SizedBox(
                      height: 200, // Adjust height as needed
                      child: Lottie.asset(
                        'assets/animation.json', // Ensure this file is present in assets
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 50), // Space before login button
                    _loginButton(),

                    // Sign-up link
                    const SizedBox(height: 100), // Space for the login button
                  ],
                ),
              ),
            ),
          ),

          // Keeps the Sign-up link *fixed at the bottom*
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(child: _signupText(context)),
          ),
        ],
      ),
    );
  }

  Widget _loginText() {
    return const Text(
      'LOGIN',
      style: TextStyle(
        // fontWeight: FontWeight.bold,
        fontSize: 64,
        color: Color.fromARGB(255, 101, 170, 181),
      ),
    );
  }

  Widget _emailField() {
    return TextField(
      controller: _emailController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: const TextStyle(color: Color.fromARGB(255, 118, 181, 200)),
        hintText: 'Enter your email',
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color.fromARGB(255, 24, 20, 20),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Added border radius
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Added border radius
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Added border radius
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: Color.fromARGB(255, 118, 181, 200)),
        hintText: 'Enter your password',
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color.fromARGB(255, 20, 18, 18),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Added border radius
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Added border radius
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Added border radius
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _loginButton() {
    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 114, 196, 203),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Login',
                style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }

  Widget _signupText(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account?",
          style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.blueGrey),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => SignupPage(post: widget.post)),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
