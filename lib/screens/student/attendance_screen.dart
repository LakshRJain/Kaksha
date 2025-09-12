import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreen createState() => _AttendanceScreen();
}

class _AttendanceScreen extends State<AttendanceScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  final blePeripheral = FlutterBlePeripheral();
  bool isBluetoothOn = false;
  bool isCheckingStatus = true;
  String studentId = "STUDENT_001"; // Replace with dynamic logic if needed

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _monitorBluetoothStatus();
  }

  // Monitor Bluetooth status
  void _monitorBluetoothStatus() {
    flutterReactiveBle.statusStream.listen((status) {
      setState(() {
        isBluetoothOn = status == BleStatus.ready;
        isCheckingStatus = false;
      });

      if (status == BleStatus.ready) {
        _startAdvertising();
        _uploadToFirestore();
      }
    });
  }

  // Request necessary permissions
  Future<void> _checkPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();
  }

  // Start BLE advertising
  void _startAdvertising() {
    final advertiseData = AdvertiseData(
      includeDeviceName: true,
      serviceUuid: "12345678-1234-5678-1234-567812345678",
    );

    blePeripheral.start(advertiseData: advertiseData);
  }

  // Upload student ID to Firestore
  void _uploadToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('attendance').add({
        'studentId': studentId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint("Uploaded to Firestore.");
    } catch (e) {
      debugPrint("Error uploading to Firestore: $e");
    }
  }

  // Show dialog to guide user for Bluetooth settings
  void _showBluetoothDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text("Open Settings",
                style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Check Bluetooth status and prompt user to turn it on if off
  void _checkBluetoothStatus() {
    if (!isBluetoothOn) {
      _showBluetoothDialog(
        title: "Bluetooth is OFF",
        message: "Please turn on Bluetooth manually in system settings.",
      );
    }
  }

  // Toggle Bluetooth manually
  Future<void> _toggleBluetooth() async {
    if (isBluetoothOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth is already ON")),
      );
    } else {
      _checkBluetoothStatus();
    }
  }

  @override
  void dispose() {
    blePeripheral.stop(); // Stop advertising
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('Give Attendance',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isCheckingStatus
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/attendance.json',
                    width: 400,
                    height: 400,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 80),
                  ElevatedButton.icon(
                    onPressed: _toggleBluetooth,
                    icon: Icon(isBluetoothOn ? Icons.check : Icons.settings,
                        color: Colors.white),
                    label: Text(
                      isBluetoothOn ? 'Bluetooth is ON' : 'Turn ON Bluetooth',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBluetoothOn
                          ? const Color.fromARGB(255, 91, 196, 96)
                          : const Color(0xFFBF616A),
                      minimumSize: const Size(220, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
