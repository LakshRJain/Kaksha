import 'package:classcare/models/user_model.dart';
import 'package:classcare/screens/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import your face registration view and feature extractor
import '../face/register_face/register_face_view.dart';

class SignupPage extends StatefulWidget {
  final String post;
  const SignupPage({super.key, required this.post});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  // Store face features after registration
  FaceFeatures? _faceFeatures;
  String? _faceImage;
  Future<void> _registerFace() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterFaceView(),
      ),
    );
    if (result != null && result is Map) {
      setState(() {
        _faceFeatures = result['faceFeatures'] as FaceFeatures;
        _faceImage = result['image'] as String;
      });
    }
  }

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = "Passwords do not match";
        });
        return;
      }
      if (widget.post == "Student" &&
          (_faceFeatures == null || _faceImage == null)) {
        setState(() {
          _errorMessage = "Please register your face before signing up.";
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Create user in Firebase Authentication
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final uid = userCredential.user!.uid;

        // Build userData map for Firestore
        final Map<String, dynamic> userData = {
          'uid': uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': widget.post,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Only add face details if the role is Student
        if (widget.post == "Student") {
          userData['faceFeatures'] = _faceFeatures?.toJson();
          userData['image'] = _faceImage;
        }

        // Save user record in Firestore under `users/{uid}`
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData, SetOptions(merge: true));

        setState(() {
          _isLoading = false;
        });

        // Success dialog
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Verify Your Email"),
            content: const Text(
                "A verification email has been sent to your inbox. Please verify to proceed."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LoginPage(post: widget.post)),
                  );
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message;
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'SIGN UP',
                    style: TextStyle(
                      fontSize: 64,
                      color: Color.fromARGB(255, 101, 170, 181),
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Full Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.person, color: Colors.white),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    style: const TextStyle(
                        color: Color.fromARGB(255, 101, 170, 181)),
                    validator: (value) =>
                        value!.isEmpty ? "Enter your name" : null,
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    style: const TextStyle(
                        color: Color.fromARGB(255, 101, 170, 181)),
                    validator: (value) =>
                        value!.isEmpty ? "Enter your email" : null,
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    style: const TextStyle(
                        color: Color.fromARGB(255, 101, 170, 181)),
                    validator: (value) =>
                        value!.length < 6 ? "Password too short" : null,
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    style: const TextStyle(
                        color: Color.fromARGB(255, 101, 170, 181)),
                    validator: (value) =>
                        value!.isEmpty ? "Confirm password" : null,
                  ),
                  const SizedBox(height: 20),

                  // Face Registration Button
                  widget.post == "Student"
                      ? SizedBox(
                          width: 200,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _registerFace,
                            icon: Icon(
                              _faceFeatures == null
                                  ? Icons.face_retouching_off
                                  : Icons.verified_user,
                              color: Colors.white,
                            ),
                            label: Text(
                              _faceFeatures == null
                                  ? "Register Face"
                                  : "Face Registered",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Color.fromARGB(255, 114, 196, 203)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        )
                      : const SizedBox(height: 10),

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Color.fromARGB(255, 101, 170, 181),
                            fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 60),

                  // Sign Up Button
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: 200,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 114, 196, 203),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account?",
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
                                builder: (context) =>
                                    LoginPage(post: widget.post)),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
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
