import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:classcare/screens/student/StudentClassDetails.dart';

class homeStudent extends StatefulWidget {
  const homeStudent({super.key});

  @override
  _homeStudentstate createState() => _homeStudentstate();
}

class _homeStudentstate extends State<homeStudent> {
  final TextEditingController _joinCodeController = TextEditingController();
  late String _studentName = 'Loading...';
  bool _isLoading = true;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchStudentName();
  }

  Future<void> fetchStudentName() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String studentId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      setState(() {
        _studentName = studentDoc['name'] ?? 'Unknown Student';
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching student name: $e");
      _showSnackBar('Failed to fetch student name.', isError: true);
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

  Future<void> joinClass(String joinCode) async {
    try {
      // Search for the class with the given join code
      QuerySnapshot classSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('joinCode', isEqualTo: joinCode)
          .limit(1)
          .get();

      if (classSnapshot.docs.isNotEmpty) {
        var classDoc = classSnapshot.docs.first;
        String userId = FirebaseAuth.instance.currentUser!.uid;

        // Save student ID to Firestore
        await classDoc.reference.update({
          'students': FieldValue.arrayUnion([userId]),
        });

        _showSnackBar('Joined class successfully!');
        Navigator.pop(context); // Close the join class dialog
      } else {
        _showSnackBar('Invalid join code.', isError: true);
      }
    } catch (e) {
      print("Error joining class: $e");
      _showSnackBar('Failed to join class. Try again.', isError: true);
    }
  }

  Widget buildStudentClassList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .where('students',
              arrayContains: FirebaseAuth.instance.currentUser!.uid)
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
                    Icons.school_outlined,
                    size: 50,
                    color: AppColors.tertiaryText,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No Classes Joined",
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
                    "Join your first class with the button below",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.tertiaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => openJoinClassDialog(),
                  icon: Icon(Icons.add),
                  label: Text("Join Class"),
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
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var classData = doc.data() as Map<String, dynamic>;

              // Parse color from hex string stored in Firestore
              String colorHex = classData['color'] ?? '#FFFFFF';
              Color cardColor = Color(
                  int.parse(colorHex.substring(1), radix: 16) | 0xFF000000);

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
                              builder: (context) => StudentClassDetails(
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

  void openJoinClassDialog() {
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
                "Join a Class",
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _joinCodeController,
                style: const TextStyle(color: AppColors.primaryText),
                cursorColor: AppColors.accentBlue,
                decoration: InputDecoration(
                  labelText: 'Enter Join Code',
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
                  prefixIcon: Icon(Icons.vpn_key, color: AppColors.accentBlue),
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
                      if (_joinCodeController.text.trim().isNotEmpty) {
                        joinClass(_joinCodeController.text.trim());
                        _joinCodeController.clear();
                      } else {
                        _showSnackBar('Please enter a join code',
                            isError: true);
                      }
                    },
                    child: const Text(
                      "Join",
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
                Icons.person_outline,
                color: AppColors.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Student Dashboard",
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  _isLoading ? "Loading..." : "Hello $_studentName",
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
          padding:
              const EdgeInsets.only(top: 16), // Added extra top padding here
          child: buildStudentClassList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openJoinClassDialog,
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

// AppColors class definition (copy from the teacher dashboard)
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
