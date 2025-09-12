import 'dart:math';
import 'package:classcare/screens/teacher/classDetailsPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _slotController = TextEditingController();
  late String _teacherName = 'Loading...';
  bool _isLoading = true;
  int _colorIndex = 0;

  @override
  void dispose() {
    _classNameController.dispose();
    _slotController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchTeacherName();
  }

  String generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> fetchTeacherName() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String teacherId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .get();

      setState(() {
        _teacherName = teacherDoc['name'] ?? 'Unknown Teacher';
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching teacher name: $e");
      _showSnackBar('Failed to fetch teacher name.', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.accentRed : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> createClass(String className, String slot) async {
    try {
      String classId =
          FirebaseFirestore.instance.collection('classes').doc().id;

      // Generate a random join code
      String joinCode = generateJoinCode();

      // List of pastel colors
      List<Color> availableColors = [
        Colors.cyan.shade200, // Cyan
        Colors.pink.shade200, // Pink
        Colors.purple.shade200, // Purple
        Colors.green.shade200, // Green
        Colors.blue.shade200, // Blue
      ];

      // Use sequential selection with cycling through the list
      Color selectedColor = availableColors[_colorIndex];
      _colorIndex = (_colorIndex + 1) % availableColors.length;

      // Convert the color to a hex string to store in Firestore
      String colorHex =
          '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

      await FirebaseFirestore.instance.collection('classes').doc(classId).set({
        'classId': classId,
        'className': className,
        'slot': slot,
        'teacherId': FirebaseAuth.instance.currentUser!.uid,
        'joinCode': joinCode, // Store the join code
        'color': colorHex,
        'teacherName': _teacherName,
      });

      _showSnackBar('Class created successfully!');
      Navigator.pop(context); // Close the create class dialog
    } catch (e) {
      print("Error creating class: $e");
      _showSnackBar('Failed to create class. Try again.', isError: true);
    }
  }

  void openCreateClassDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Create New Class",
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _classNameController,
                style: const TextStyle(color: AppColors.primaryText),
                cursorColor: AppColors.accentBlue,
                decoration: InputDecoration(
                  labelText: 'Class Name',
                  labelStyle: TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.accentBlue),
                  ),
                  prefixIcon: Icon(Icons.class_, color: AppColors.accentBlue),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _slotController,
                style: const TextStyle(color: AppColors.primaryText),
                cursorColor: AppColors.accentBlue,
                decoration: InputDecoration(
                  labelText: 'Slot',
                  labelStyle: TextStyle(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.accentBlue),
                  ),
                  prefixIcon:
                      Icon(Icons.access_time, color: AppColors.accentBlue),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (_classNameController.text.trim().isNotEmpty &&
                          _slotController.text.trim().isNotEmpty) {
                        createClass(_classNameController.text.trim(),
                            _slotController.text.trim());
                        _classNameController.clear();
                        _slotController.clear();
                      } else {
                        _showSnackBar('Please fill all fields', isError: true);
                      }
                    },
                    child: const Text(
                      "Create",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildClassList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accentBlue,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.class_outlined,
                    size: 50,
                    color: AppColors.tertiaryText,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No Classes Available",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 240,
                  child: Text(
                    "Start by creating your first class with the button below",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.tertiaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: openCreateClassDialog,
                  icon: Icon(Icons.add),
                  label: Text("Create Class"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              16, 24, 16, 16), // Added top padding of 24
          child: ListView.builder(
            // Removed padding: EdgeInsets.only(top: 12) here to avoid double padding
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var classData = doc.data() as Map<String, dynamic>;

              // Parse color from hex string stored in Firestore
              Color cardColor = Color(int.parse(
                    classData['color'].substring(1),
                    radix: 16,
                  ) |
                  0xFF000000);

              return Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 16),
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData['className'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Slot: ${classData['slot']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Teacher Name: ${classData['teacherName']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassDetailPage(
                                classId: classData['classId'],
                                className: classData['className'],
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Text("View Class"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school,
                color: AppColors.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Teacher Dashboard",
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  _isLoading ? "Loading..." : "Hello, $_teacherName",
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.logout,
                color: AppColors.accentRed,
                size: 20,
              ),
            ),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.accentRed.withOpacity(0.1),
                          radius: 32,
                          child: Icon(
                            Icons.logout,
                            color: AppColors.accentRed,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Are you sure you want to log out?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.secondaryText,
                                  side:
                                      BorderSide(color: AppColors.surfaceColor),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await FirebaseAuth.instance.signOut();
                                  Navigator.pop(context); // Close the dialog
                                  Navigator.pushReplacementNamed(context,
                                      '/start'); // Navigate to login screen
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentRed,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text('Logout'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            tooltip: 'Logout',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
              top: 16), // Added top padding to match student dashboard
          child: buildClassList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openCreateClassDialog,
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// AppColors class definition
class AppColors {
  static const Color background = Color.fromARGB(255, 27, 26, 27);
  static const Color cardColor = Color.fromARGB(255, 45, 45, 45);
  static const Color surfaceColor = Color.fromARGB(255, 58, 58, 58);
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color.fromARGB(255, 200, 200, 200);
  static const Color tertiaryText = Color.fromARGB(255, 150, 150, 150);
  static const Color accentBlue = Color.fromARGB(255, 76, 139, 245);
  static const Color accentGreen = Color.fromARGB(255, 79, 190, 123);
  static const Color accentRed = Color.fromARGB(255, 232, 117, 117);
  static const Color accentYellow = Color.fromARGB(255, 255, 196, 0);
  static const Color accentPurple = Color.fromARGB(255, 151, 93, 243);
}
