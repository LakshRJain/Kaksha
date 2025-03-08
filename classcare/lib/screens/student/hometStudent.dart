import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:classcare/screens/student/StudentClassDetails.dart'; // Make sure to import the correct page for class details

class homeStudent extends StatefulWidget {
  const homeStudent({super.key});

  @override
  _homeStudentstate createState() => _homeStudentstate();
}

class _homeStudentstate extends State<homeStudent> {
  final TextEditingController _joinCodeController = TextEditingController();

  // Display the classes the student has joined
  Widget buildStudentClassList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .where('students',
              arrayContains: FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("You have not joined any classes."));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var classData = doc.data() as Map<String, dynamic>;
            String colorHex = classData['color'] ??
                '#FFFFFF'; // Default to white if no color is found
            Color cardColor = Color(int.parse('0xFF${colorHex.substring(1)}'));
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                color: cardColor,
                elevation: 5, // Add elevation for a shadow effect
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData['className'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Slot: ${classData['slot']}",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Teacher Name: ${classData['teacherName']}",
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
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
                          backgroundColor: Colors.white, // Button color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'View Class',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Function for the student to join a class using a join code

  // Updated joinClass function to include Bluetooth address
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

        // Get device ID
        // final deviceInfoPlugin = DeviceInfoPlugin();
        // String deviceId = '';
        // if (Theme.of(context).platform == TargetPlatform.android) {
        //   var androidInfo = await deviceInfoPlugin.androidInfo;
        //   deviceId = androidInfo.id; // Unique device ID for Android
        // } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        //   var iosInfo = await deviceInfoPlugin.iosInfo;
        //   deviceId = iosInfo.identifierForVendor ??
        //       'Unknown'; // Unique device ID for iOS
        // }

        // Get Bluetooth address
        // String bluetoothAddress = await _getBluetoothAddress();

        // Save student ID, device ID, and Bluetooth address to Firestore
        await classDoc.reference.update({
          'students': FieldValue.arrayUnion([userId]),
        });
        // try {
        //   await FirebaseFirestore.instance
        //       .collection('classes')
        //       .doc(classDoc.id)
        //       .collection('students')
        //       .doc(userId)
        //       .set({
        //     'deviceId': deviceId,
        //     'bluetoothAddress': bluetoothAddress,
        //   });
        //   print("Data saved successfully.");
        // } catch (e) {
        //   print("Firestore error: $e");
        // }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined class successfully!')),
        );
        Navigator.pop(context); // Close the join class dialog
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid join code.')),
        );
      }
    } catch (e) {
      print("Error joining class: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join class. Try again.')),
      );
    }
  }

  // UI for entering the join code
  Widget buildJoinClassForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
            controller: _joinCodeController,
            decoration: InputDecoration(
              labelText: 'Enter Join Code',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              joinClass(_joinCodeController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Button color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Join Class'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Logout'),
                  content: Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pop(context); // Close the dialog
                        Navigator.pushReplacementNamed(
                            context, '/start'); // Navigate to login screen
                      },
                      child: Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title for student dashboard
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Your Classes",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Show classes student has joined
          Expanded(
            child: buildStudentClassList(),
          ),
          // Button for student to join a class using the join code
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Join a Class'),
                      content: buildJoinClassForm(),
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Button color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Join a New Class'),
            ),
          ),
        ],
      ),
    );
  }
}
