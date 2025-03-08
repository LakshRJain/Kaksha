import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class TakeAttendancePage extends StatefulWidget {
  const TakeAttendancePage({super.key, required this.ClassId});
  final String ClassId;

  @override
  _TakeAttendancePageState createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  Map<String, Map<String, String>> bluetoothMap = {};
  List<Map<String, dynamic>> detectedDevices =
      []; // This stays as Map<String, dynamic>
  bool isScanning = false;
  StreamSubscription<DiscoveredDevice>? scanSubscription;
  StreamSubscription<BluetoothDiscoveryResult>? classicScanSubscription;
  double distanceThreshold = 5.0; // Default distance threshold in meters

  @override
  void initState() {
    super.initState();
    getBluetoothAddresses();
    _initializeNotifications();
    _checkPermissions();
    _startScanning(); // Start scanning immediately when the page opens
  }

  @override
  void dispose() {
    _stopScanning(); // Stop scanning when the page is disposed
    super.dispose();
  }

  /// Request necessary Android permissions at runtime
  Future<void> _checkPermissions() async {
    if (await Permission.bluetoothScan.isDenied ||
        await Permission.bluetoothConnect.isDenied ||
        await Permission.location.isDenied ||
        await Permission.notification.isDenied) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.notification
      ].request();
    }
  }

  void getBluetoothAddresses() {
    FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.ClassId)
        .collection('students')
        .snapshots() // Listen to real-time updates
        .listen((snapshot) {
      Map<String, Map<String, String>> updatedBluetoothMap = {};
      for (var doc in snapshot.docs) {
        String studentId = doc.id;
        String bluetoothAddress = doc.get('bluetoothAddress');
        String name = doc.get('name'); // Get the name field
        updatedBluetoothMap[studentId] = {
          'name': name,
          'bluetoothAddress': bluetoothAddress,
        };
      }
      setState(() {
        bluetoothMap =
            updatedBluetoothMap; // Update the map with real-time data
      });
    }, onError: (e) {
      print('Error listening to Bluetooth addresses: $e');
    });
  }

  /// Initialize local notifications
  void _initializeNotifications() {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    localNotifications.initialize(initSettings);
  }

  /// Convert RSSI to approximate distance in meters
  double _rssiToDistance(int rssi) {
    const int A = -59; // RSSI at 1 meter
    const double n = 2.0; // Environmental factor (2.0 for free-space)
    return pow(10, (A - rssi) / (10 * n)).toDouble();
  }

  /// Start scanning for BLE devices with distance filtering
  void _startScanning() {
    setState(() {
      detectedDevices.clear();
      isScanning = true;
    });

    // BLE scanning using flutter_reactive_ble
    scanSubscription = flutterReactiveBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.balanced,
    ).listen((device) {
      double distance = _rssiToDistance(device.rssi);
      if (distance <= distanceThreshold) {
        // Check if the Bluetooth address is in bluetoothMap
        if (bluetoothMap.values
            .any((value) => value['bluetoothAddress'] == device.id)) {
          String? studentName;
          String? studentId;
          bluetoothMap.forEach((key, value) {
            if (value['bluetoothAddress'] == device.id) {
              studentName = value['name']; // Get the name from the map
              studentId = key;
            }
          });
          if (!detectedDevices.any((d) => d['id'] == device.id)) {
            setState(() {
              detectedDevices.add({
                'name': studentName ?? "Unknown BLE Device",
                'id': device.id,
                'rssi': device.rssi,
                'distance': distance,
                'type': 'BLE',
              });
            });
            _sendNotification(studentName ?? "Unknown BLE Device");
            if (studentId != null && studentName != null) {
              saveAttendance(studentId!, studentName!); // Save to Firestore
            }
          }
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("Error scanning: $error");
      }
      setState(() => isScanning = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error scanning: $error")),
      );
    });

    // Classic Bluetooth scanning
    classicScanSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      // Check if the Bluetooth address is in bluetoothMap
      if (bluetoothMap.values
          .any((value) => value['bluetoothAddress'] == result.device.address)) {
        String? studentName;
        String? studentId;
        bluetoothMap.forEach((key, value) {
          if (value['bluetoothAddress'] == result.device.address) {
            studentName = value['name']; // Get the name from the map
            studentId = key;
          }
        });
        if (!detectedDevices.any((d) => d['id'] == result.device.address)) {
          setState(() {
            detectedDevices.add({
              'name': studentName ?? "Unknown Classic Device",
              'id': result.device.address,
              'rssi': result.rssi ?? -80, // Provide a default value if null
              'distance':
                  result.rssi != null ? _rssiToDistance(result.rssi) : null,
              'type': 'Classic',
            });
          });
          if (studentId != null && studentName != null) {
            saveAttendance(studentId!, studentName!); // Save to Firestore
          }
          // _sendNotification(studentName ?? "Unknown Classic Device");
        }
      }
    });
  }

  /// Stop BLE scanning
  void _stopScanning() {
    setState(() => isScanning = false);
    scanSubscription?.cancel();
    classicScanSubscription?.cancel();
  }

  Future<void> saveAttendance(String studentId, String studentName) async {
    try {
      final now = DateTime.now();
      final date = "${now.day}-${now.month}-${now.year}";
      final time = "${now.hour}:${now.minute}:${now.second}";

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.ClassId)
          .collection('attendancehistory')
          .doc(date) // Use studentId as document ID
          .set({
        '$studentName-$studentId': {
          'name': studentName,
          'time': time,
        }
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print("Attendance saved for $studentName at $time on $date");
      }
    } catch (e) {
      print("Error saving attendance: $e");
    }
  }

  /// Send local notification when a device is detected
  void _sendNotification(String deviceName) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    await localNotifications.show(
        0, "Student Detected", "$deviceName is nearby!", notificationDetails);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Take Attendance"),
        actions: [
          if (detectedDevices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {}, // Placeholder for saving attendance
              tooltip: "Save Attendance",
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isScanning ? Colors.green.shade100 : Colors.orange.shade100,
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isScanning
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth_disabled),
                const SizedBox(width: 10),
                Text(isScanning ? "Scanning for devices..." : "Scan stopped"),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Set Detection Range (meters):",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: distanceThreshold,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: "${distanceThreshold.toStringAsFixed(1)} m",
                  onChanged: (value) {
                    setState(() => distanceThreshold = value);
                  },
                ),
                Text(
                    "Current Range: ${distanceThreshold.toStringAsFixed(1)} meters",
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: detectedDevices.length,
              itemBuilder: (context, index) {
                final device = detectedDevices[index];
                // Access the distance from the map, not calculating it again
                final distance = device['distance'] ?? 'Unknown';
                final distanceText = distance is double
                    ? "${distance.toStringAsFixed(2)} m"
                    : "Unknown";

                return ListTile(
                  title: Text(
                    "  " + device['name'] ?? "Unknown Device",
                    style: TextStyle(fontSize: 20),
                  ),
                  trailing: const Icon(Icons.check, color: Colors.green),
                );
              },
            ),
          ),
          if (!isScanning)
            ElevatedButton(
              onPressed: _startScanning,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Start Scanning"),
            ),
          if (isScanning)
            ElevatedButton(
              onPressed: _stopScanning,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Stop Scanning"),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
