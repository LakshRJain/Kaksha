import 'package:classcare/screens/student/attendance_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:classcare/screens/student/assignment_list.dart';
import 'package:classcare/screens/teacher/chat_tab.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';

// Refined color palette with subtle tones - copied from the first file
class AppColors {
  // Base colors
  static const Color background = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF252525);

  // Subtle accent colors
  static const Color accentBlue = Color(0xFF81A1C1);
  static const Color accentGreen = Color.fromARGB(255, 125, 225, 130);
  static const Color accentPurple = Color(0xFFB48EAD);
  static const Color accentYellow = Color(0xFFEBCB8B);
  static const Color accentRed = Color(0xFFBF616A);

  // Text colors
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color(0xFFAAAAAA);
  static const Color tertiaryText = Color(0xFF757575);
}

class StudentClassDetails extends StatefulWidget {
  final String classId;
  final String className;

  const StudentClassDetails({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  _StudentClassDetailsState createState() => _StudentClassDetailsState();
}

class _StudentClassDetailsState extends State<StudentClassDetails>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0; // Track the current tab index explicitly

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Add listener to update state when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index; // Update the current index
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<DocumentSnapshot> getClassDetails() async {
    return FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .get();
  }

  void _giveAttendance() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    String name = "";
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      name = doc.get('name'); // Extracting the 'name' field
    } else {
      print("User document does not exist.");
      return null;
    }
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = '';
    if (Theme.of(context).platform == TargetPlatform.android) {
      var androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id; // Unique device ID for Android
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      var iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId =
          iosInfo.identifierForVendor ?? 'Unknown'; // Unique device ID for iOS
    }

    String bluetoothAddress = await _getBluetoothAddress();
    print(bluetoothAddress);
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(userId)
          .set({
        'deviceId': deviceId,
        'bluetoothAddress': bluetoothAddress,
        'name': name,
      });
      print("Data saved successfully.");
    } catch (e) {
      print("Firestore error: $e");
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance recorded successfully!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: AppColors.accentGreen.withOpacity(0.8),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => AttendanceScreen()));
  }

  Future<String> _getBluetoothAddress() async {
    try {
      await FlutterBluePlus.turnOn();

      // Get the Bluetooth address
      String? bluetoothAddress;
      if (Theme.of(context).platform == TargetPlatform.android) {
        List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;

        if (devices.isNotEmpty) {
          bluetoothAddress = devices.first.remoteId.toString();
        } else {
          // If no connected devices, try scanning
          await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

          // Wait for scan results
          await Future.delayed(Duration(seconds: 4));

          // Get scan results and extract devices
          List<ScanResult> scanResults =
              await FlutterBluePlus.scanResults.first;

          if (scanResults.isNotEmpty) {
            bluetoothAddress = scanResults.first.device.remoteId.toString();
          } else {
            bluetoothAddress = 'Android-Bluetooth-Unknown';
          }

          // Stop scanning
          FlutterBluePlus.stopScan();
        }
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        // On iOS, getting Bluetooth address directly is challenging
        bluetoothAddress = 'iOS-Bluetooth-Address-Placeholder';
      }

      return bluetoothAddress ?? 'Unknown';
    } catch (e) {
      print("Error getting Bluetooth address: $e");
      return 'Unknown';
    }
  }

  // Function to handle tab selection
  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _tabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: w * 0.01,
        ),
        cardColor: AppColors.cardColor,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.className,
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: h * 0.02,
            ),
          ),
        ),
        body: Column(
          children: [
            // Class header section
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.all(h * 0.018),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentBlue.withOpacity(0.2),
                    AppColors.accentPurple.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(w * 0.03),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: AppColors.accentBlue,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Student Dashboard",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ],
              ),
            ),

            // Give Attendance Button - Styled to match the first file's design
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _giveAttendance,
                icon: Icon(Icons.check_circle, color: AppColors.background),
                label: Text(
                  'Give Attendance',
                  style: TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: AppColors.background,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(w * 0.03),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            // Custom boxed tab bar with fixed segments - matches the first file design
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(w * 0.03),
              ),
              child: Row(
                children: [
                  // Assignments Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 0
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _currentIndex == 0
                              ? Border.all(
                                  color: AppColors.accentBlue.withOpacity(0.5),
                                  width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              color: _currentIndex == 0
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Assignments",
                              style: TextStyle(
                                color: _currentIndex == 0
                                    ? AppColors.accentBlue
                                    : AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Chat Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 1
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(w * 0.03),
                          border: _currentIndex == 1
                              ? Border.all(
                                  color: AppColors.accentBlue.withOpacity(0.5),
                                  width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: _currentIndex == 1
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Chat",
                              style: TextStyle(
                                color: _currentIndex == 1
                                    ? AppColors.accentBlue
                                    : AppColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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

            // Tab content - styled to match the first file
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(w * 0.03),
                ),
                clipBehavior: Clip.antiAlias,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AssignmentList(classId: widget.classId),
                    ChatTab(classId: widget.classId),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
