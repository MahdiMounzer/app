import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:battery/battery.dart'; // Updated import
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  int batteryPercentage = -1;
  final Battery _battery = Battery();

  @override
  void initState() {
    super.initState();
    scanForDevices();
    startBatteryMonitoring();
  }

  void scanForDevices() {
    flutterBlue.startScan(timeout: Duration(seconds: 4));
    flutterBlue.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!devices.contains(result.device)) {
          setState(() {
            devices.add(result.device);
          });
        }
      }
    });
    flutterBlue.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        // Update this UUID to match your HM-10 characteristic UUID
        if (characteristic.uuid == Guid('00002a19-0000-1000-8000-00805f9b34fb')) {
          targetCharacteristic = characteristic;
        }
      }
    }
    setState(() {
      connectedDevice = device;
    });
  }

  void startBatteryMonitoring() {
    Timer.periodic(Duration(minutes: 1), (timer) async {
      int batteryLevel = await _battery.batteryLevel;
      setState(() {
        batteryPercentage = batteryLevel;
      });
      sendBatteryPercentage();
    });
  }

  void sendBatteryPercentage() async {
    if (targetCharacteristic != null && batteryPercentage != -1) {
      await targetCharacteristic!.write([batteryPercentage]);
      print('Sent Battery Level: $batteryPercentage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Devices'),
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(devices[index].name),
            subtitle: Text(devices[index].id.toString()),
            onTap: () {
              connectToDevice(devices[index]);
            },
          );
        },
      ),
      bottomNavigationBar: batteryPercentage != -1
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Battery Level: $batteryPercentage%'),
            )
          : null,
    );
  }
}
