import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(const MaterialApp(home: MistibotControlScreen()));

class MistibotControlScreen extends StatefulWidget {
  const MistibotControlScreen({Key? key}) : super(key: key);

  @override
  _MistibotControlScreenState createState() => _MistibotControlScreenState();
}

class _MistibotControlScreenState extends State<MistibotControlScreen> {
  // Use your robot's static WireGuard VPN IP address
  final String _robotVpnIp = "ws://10.8.0.2:9090"; 
  WebSocketChannel? _channel;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToRobot();
  }

  void _connectToRobot() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_robotVpnIp));
      setState(() {
        _isConnected = true;
      });
      print("Connected to Mistibot via VPN at $_robotVpnIp");
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      print("Connection failed: $e");
    }
  }

  /// Formats and transmits a Twist message to the rosbridge server
  void _publishTwist(double linearX, double angularZ) {
    if (_channel == null || !_isConnected) {
      print("Cannot send command: Disconnected from VPN");
      return;
    }

    final rosPublishMessage = {
      "op": "publish",
      "topic": "/cmd_vel",
      "msg": {
        "linear": {"x": linearX, "y": 0.0, "z": 0.0},
        "angular": {"x": 0.0, "y": 0.0, "z": angularZ}
      }
    };

    _channel!.sink.add(jsonEncode(rosPublishMessage));
    print("Sent to ROS 2: Linear: $linearX, Angular: $angularZ");
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text("Mistibot Command Center"),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(_isConnected ? "VPN Connected" : "Disconnected"),
              backgroundColor: _isConnected ? Colors.green[700] : Colors.red[700],
            ),
          )
        ],
      ),
      body: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.blueGrey[800],
            shape: BoxShape.circle,
          ),
          child: Stack(
            children: [
              // Forward Button (Move straight ahead)
              Align(
                alignment: Alignment.topCenter,
                child: IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.arrow_circle_up, color: Colors.white),
                  onPressed: () => _publishTwist(0.3, 0.0), 
                ),
              ),
              // Left Button (Rotate counter-clockwise)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.arrow_circle_left_outlined, color: Colors.white),
                  onPressed: () => _publishTwist(0.0, 0.5),
                ),
              ),
              // Stop Button (Emergency braking)
              Align(
                alignment: Alignment.center,
                child: IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                  onPressed: () => _publishTwist(0.0, 0.0),
                ),
              ),
              // Right Button (Rotate clockwise)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.arrow_circle_right_outlined, color: Colors.white),
                  onPressed: () => _publishTwist(0.0, -0.5),
                ),
              ),
              // Backward Button (Reverse)
              Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  iconSize: 64,
                  icon: const Icon(Icons.arrow_circle_down, color: Colors.white),
                  onPressed: () => _publishTwist(-0.3, 0.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

