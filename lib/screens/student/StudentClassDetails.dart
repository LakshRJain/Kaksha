import 'package:classcare/calendar/calendar_screen.dart';
import 'package:classcare/screens/student/attendance_screen.dart';
import 'package:classcare/screens/teacher/students_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:classcare/screens/student/assignment_list.dart';
import 'package:classcare/screens/teacher/chat_tab.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:classcare/screens/student/studentQuiz.dart';
import 'package:classcare/widgets/Colors.dart';
import 'package:classcare/face/authenticate_face/authenticate_face_view.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AuthenticateFaceView(
                userId: userId,
              )),
    );

    if (result == true) {
      // ✅ Only after face auth succeeds
      setState(() => _isLoading = true);

      try {
        String name = "";
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (doc.exists) {
          name = doc.get('name');
        }

        final deviceInfoPlugin = DeviceInfoPlugin();
        String deviceId = '';
        if (Theme.of(context).platform == TargetPlatform.android) {
          var androidInfo = await deviceInfoPlugin.androidInfo;
          deviceId = androidInfo.id;
        } else if (Theme.of(context).platform == TargetPlatform.iOS) {
          var iosInfo = await deviceInfoPlugin.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? 'Unknown';
        }

        String bluetoothAddress = await _getBluetoothAddress();

        await FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(userId)
            .set({
          'deviceId': deviceId,
          'bluetoothAddress': bluetoothAddress,
          'name': name,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        Navigator.push(context,
            MaterialPageRoute(builder: (context) => AttendanceScreen()));
      } catch (e) {
        print("Error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error saving attendance"),
              backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // ❌ Authentication failed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Face authentication failed. Attendance not recorded.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
        drawer: Drawer(
            backgroundColor: AppColors.surfaceColor,
            child: ListView(padding: EdgeInsets.zero, children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: AppColors.accentBlue,
                      size: h * 0.04,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Class Options",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: h * 0.02,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.quiz, color: AppColors.accentYellow),
                title: Text("Quiz",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              Studentquiz(classId: widget.classId)));
                },
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_sharp,
                    color: AppColors.accentPurple),
                title: Text("Calendar",
                    style: TextStyle(color: AppColors.primaryText)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CalendarScreen(
                                classId: widget.classId,
                                className: widget.className,
                                isTeacher: false,
                              )));
                },
              ),
              ListTile(
                leading: Icon(Icons.bluetooth, color: AppColors.accentGreen),
                title: _isLoading
                    ? Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.primaryText,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                        ],
                      )
                    : Text(
                        "BLE Attendance",
                        style: TextStyle(color: AppColors.primaryText),
                      ),
                onTap: _isLoading
                    ? null
                    : () async {
                        // Show the pop-up dialog first
                        bool? confirmed = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            titlePadding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                            contentPadding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                            actionsPadding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                            title: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accentBlue.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.bluetooth_disabled_rounded,
                                    color: AppColors.accentBlue,
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Turn off Bluetooth',
                                    style: TextStyle(
                                      color: AppColors.primaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Before proceeding with BLE Attendance, please turn off your Bluetooth.',
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.settings_rounded,
                                          color: AppColors.accentBlue,
                                          size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Open Settings > Bluetooth > Switch Off',
                                          style: TextStyle(
                                            color: AppColors.primaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: AppColors.accentBlue
                                          .withOpacity(0.6)),
                                  foregroundColor: AppColors.accentBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accentBlue,
                                  foregroundColor: AppColors.primaryText,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text('I turned it off'),
                              ),
                            ],
                          ),
                        );

                        // If user pressed OK, call _giveAttendance
                        if (confirmed ?? false) {
                          _giveAttendance();
                        }
                      },
              )
            ])),
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
                borderRadius: BorderRadius.circular(20),
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

            // Custom boxed tab bar with fixed segments - matches the first file design
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 0
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
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
                              "Student List",
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
                  // Assignments Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 1
                              ? AppColors.cardColor
                              : const Color.fromARGB(0, 28, 24, 24),
                          borderRadius: BorderRadius.circular(20),
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
                              Icons.assignment_outlined,
                              color: _currentIndex == 1
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Assignments",
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

                  // Chat Tab
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTab(2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentIndex == 2
                              ? AppColors.cardColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: _currentIndex == 2
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
                              color: _currentIndex == 2
                                  ? AppColors.accentBlue
                                  : AppColors.secondaryText,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Chat",
                              style: TextStyle(
                                color: _currentIndex == 2
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
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    StudentsList(
                      classId: widget.classId,
                      post: "student",
                    ),
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
