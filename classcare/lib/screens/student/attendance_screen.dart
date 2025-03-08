import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreen createState() => _AttendanceScreen();
}

class _AttendanceScreen extends State<AttendanceScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  bool isBluetoothOn = false;
  bool isCheckingStatus = true;

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
    });
  }

  // Request necessary permissions
  Future<void> _checkPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // Show dialog to guide user for Bluetooth settings
  void _showBluetoothDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings(); // Opens app settings to manage Bluetooth
            },
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
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

  // Toggle Bluetooth status
  Future<void> _toggleBluetooth() async {
    if (isBluetoothOn) {
      // No action if Bluetooth is already ON
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth is already ON")),
      );
    } else {
      // Suggest user turn on Bluetooth manually
      _showBluetoothDialog(
        title: "Turn On Bluetooth",
        message:
            "Bluetooth is off. Please turn it on manually in system settings.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Control'),
      ),
      body: isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isBluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                    size: 80,
                    color: isBluetoothOn ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBluetoothOn ? 'Bluetooth is ON' : 'Bluetooth is OFF',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _toggleBluetooth,
                    icon: Icon(isBluetoothOn ? Icons.check : Icons.settings),
                    label: Text(isBluetoothOn
                        ? 'Bluetooth is ON'
                        : 'Turn ON Bluetooth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isBluetoothOn ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
