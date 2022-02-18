import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import './ChatPage.dart';
import './SelectBondedDevicePage.dart';
import 'package:drawingrobot/home.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => new _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address = "...";
  String _name = "...";

  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  bool _autoAcceptPairingRequests = false;

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if ((await FlutterBluetoothSerial.instance.isEnabled) ?? false) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address!;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name!;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // Discoverable mode is disabled when Bluetooth gets disabled
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('Bluetooth Drawing Robot'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // Color(0xFFffd200),
              // Color(0xFFF7971E),
              Color.fromRGBO(138, 35, 135, 1.0),
              Color.fromRGBO(233, 64, 87, 1.0),
              Color.fromRGBO(242, 113, 33, 1.0)
            ],
          ),
        ),
        child: ListView(
          children: <Widget>[
            Divider(),
            ListTile(title: const Text('General')),
            SwitchListTile(
              activeColor: Colors.black87,
              activeTrackColor: Colors.black87,
              inactiveThumbColor: Colors.grey.shade900,
              inactiveTrackColor: Colors.grey.shade900,
              title: const Text('Enable Bluetooth'),
              value: _bluetoothState.isEnabled,
              onChanged: (bool value) {
                // Do the request and update with the true value then
                future() async {
                  // async lambda seems to not working
                  if (value)
                    await FlutterBluetoothSerial.instance.requestEnable();
                  else
                    await FlutterBluetoothSerial.instance.requestDisable();
                }

                future().then((_) {
                  setState(() {});
                });
              },
            ),
            ListTile(
              title: const Text('Bluetooth status'),
              subtitle: Text(_bluetoothState.toString()),
              trailing: ElevatedButton(
                child: const Text('Settings'),
                style: ElevatedButton.styleFrom(
                    primary: Colors.black87,
                    textStyle: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () {
                  FlutterBluetoothSerial.instance.openSettings();
                },
              ),
            ),
            Divider(),
            ListTile(title: const Text('Devices discovery and connection')),
            Divider(),
            ListTile(
              title: ElevatedButton(
                child: const Text('Connect to paired device to chat'),
                style: ElevatedButton.styleFrom(
                    primary: Colors.black87,
                    textStyle: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () async {
                  final BluetoothDevice? selectedDevice =
                      await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(checkAvailability: true);
                      },
                    ),
                  );

                  if (selectedDevice != null) {
                    // BluetoothConnection.toAddress(selectedDevice.address)
                    //     .then((_connection) {
                    //   var connection = _connection;
                    //   connection.output.add(
                    //       Uint8List.fromList(utf8.encode("T105" + "\r\n")));
                    // });
                    print('Connect -> selected ' + selectedDevice.address);
                    _startChat(context, selectedDevice);
                  } else {
                    print('Connect -> no device selected');
                  }
                },
              ),
            ),
            Divider(),
            ListTile(
              title: ElevatedButton(
                child: const Text('Connect to a paired device and Draw'),
                style: ElevatedButton.styleFrom(
                    primary: Colors.black87,
                    textStyle: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () async {
                  final BluetoothDevice? selectedDevice =
                      await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(checkAvailability: true);
                      },
                    ),
                  );

                  if (selectedDevice != null) {
                    // BluetoothConnection.toAddress(selectedDevice.address)
                    //     .then((_connection) {
                    //   var connection = _connection;
                    //   connection.output.add(
                    //       Uint8List.fromList(utf8.encode("T105" + "\r\n")));
                    // });
                    print('Connect -> selected ' + selectedDevice.address);
                    _startDraw(context, selectedDevice);
                    // _startDraw(context);
                  } else {
                    print('Connect -> no device selected');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat(BuildContext context, BluetoothDevice server) {
    SchedulerBinding.instance?.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return ChatPage(server: server);
          },
        ),
      );
    });
  }

  void _startDraw(BuildContext context, BluetoothDevice server) {
    // void _startDraw(BuildContext context) {
    SchedulerBinding.instance?.addPostFrameCallback((_) {
      // add your code here.

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return Home(server: server);
            // return Home();
          },
        ),
      );
    });
  }
}
