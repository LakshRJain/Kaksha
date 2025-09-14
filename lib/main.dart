import 'package:classcare/screens/getStarted.dart';
import 'package:classcare/screens/student/hometStudent.dart';
import 'package:classcare/screens/teacher/homeTeacher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  print("Loading .env...");
  // Load .env file from assets folder
  await dotenv.load(fileName: "assets/.env");

  print("Loaded .env");

  print("Requesting storage permission...");
  await Permission.storage.request();
  print("Permission granted");

  print("Initializing Firebase...");
  await Firebase.initializeApp();
  print("Firebase initialized");

  print("Activating Firebase App Check...");
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  print("Firebase App Check activated");

  User? currentUser = FirebaseAuth.instance.currentUser;
  print("Checking user authentication...");

  Widget initialScreen = const Start();
  if (currentUser != null) {
    print("User logged in: ${currentUser.uid}");
    String? role = await getUserRole(currentUser.uid);
    print("User role: $role");

    if (role == 'Student') {
      initialScreen = const homeStudent();
    } else if (role == 'Teacher') {
      initialScreen = const TeacherDashboard();
    }
  } else {
    print("No user logged in.");
  }

  print("Launching app...");
  runApp(MyApp(initialScreen: initialScreen));
}

Future<String?> getUserRole(String userId) async {
  try {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      return userDoc[
          'role']; // Assumes Firestore has field 'role'ghfghfgh dfgdfg
    }
  } catch (e) {
    print('Error getting user role: $e');
  }
  return null;
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/start': (context) => Start(),
      },
      title: 'Kaksha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: initialScreen,
    );
  }
}
