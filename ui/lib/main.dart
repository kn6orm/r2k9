import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(const R2K9App());
}

class R2K9App extends StatelessWidget {
  const R2K9App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R2K9 Teleop Dashboard',
      theme: ThemeData.dark(),
      home: const TeleopDashboard(),
    );
  }
}

class TeleopDashboard extends StatefulWidget {
  const TeleopDashboard({super.key});

  @override
  State<TeleopDashboard> createState() => _TeleopDashboardState();
}

class _TeleopDashboardState extends State<TeleopDashboard> {
  // 1. Text editing controller initialized to 'localhost' by default
  final TextEditingController _hostnameController = TextEditingController(
    text: 'localhost',
  );

  WebSocketChannel? _channel;
  StreamSubscription? _rosSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Disconnected";
  String? _immobilityAlert;

  @override
  void dispose() {
    _hostnameController.dispose();
    _closeConnection();
    super.dispose();
  }

  // 2. Dynamic connection routine using the editable text field value
  void _toggleConnection() {
    if (_isConnected) {
      _closeConnection();
    } else {
      final host = _hostnameController.text.trim();
      if (host.isEmpty) return;

      final targetUri =
          'ws://$host:9090'; // Automatically formats the editable target address

      try {
        setState(() {
          _connectionStatus = "Connecting to $targetUri...";
        });

        _channel = WebSocketChannel.connect(Uri.parse(targetUri));

        setState(() {
          _isConnected = true;
          _connectionStatus = "Connected to $host";
        });

        // Send stop command on connection
        _sendStopCommand();
        _subscribeToImmobilityAlerts();
      } catch (e) {
        setState(() {
          _connectionStatus = "Connection Failed: ${e.toString()}";
          _isConnected = false;
        });
      }
    }
  }

  void _closeConnection() {
    // Send stop command before disconnecting
    _sendStopCommand();

    if (_channel != null) {
      final unsubscribe = {"op": "unsubscribe", "topic": "/immobility_alert"};
      _channel!.sink.add(jsonEncode(unsubscribe));
    }
    _rosSubscription?.cancel();
    _channel?.sink.close();
    setState(() {
      _isConnected = false;
      _connectionStatus = "Disconnected";
      _immobilityAlert = null;
    });
  }

  // 3. Serializes and transmits continuous movement payloads over the active channel
  void _sendTwistCommand(double linearX, double angularZ) {
    if (!_isConnected || _channel == null) return;

    final Map<String, dynamic> rosbridgeMessage = {
      "op": "publish",
      "topic": "/cmd_vel",
      "msg": {
        "linear": {"x": linearX, "y": 0.0, "z": 0.0},
        "angular": {"x": 0.0, "y": 0.0, "z": angularZ},
      },
    };

    _channel!.sink.add(jsonEncode(rosbridgeMessage));
  }

  void _sendStopCommand() {
    _sendTwistCommand(0.0, 0.0);
  }

  void _dismissImmobilityAlert() {
    setState(() {
      _immobilityAlert = null;
    });
  }

  void _subscribeToImmobilityAlerts() {
    if (!_isConnected || _channel == null) return;

    final subscribePayload = {"op": "subscribe", "topic": "/immobility_alert"};
    _channel!.sink.add(jsonEncode(subscribePayload));

    _rosSubscription = _channel!.stream.listen(
      (dynamic message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          if (decoded["op"] == "publish" &&
              decoded["topic"] == "/immobility_alert") {
            final msg = decoded["msg"] as Map<String, dynamic>;
            final String alertText =
                msg["message"] as String? ?? msg.toString();
            setState(() {
              _immobilityAlert = alertText;
            });
          }
        } catch (_) {
          // Ignore malformed ROSBridge messages
        }
      },
      onError: (_) {
        setState(() {
          _immobilityAlert = null;
        });
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _immobilityAlert = null;
            _isConnected = false;
            _connectionStatus = "Disconnected";
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('R2K9 UI Interface')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- HOSTNAME CONFIGURATION LAYER ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hostnameController,
                        enabled:
                            !_isConnected, // Prevent edits while actively connected
                        decoration: const InputDecoration(
                          labelText: 'Robot Hostname / VPN IP',
                          hintText: 'e.g., 10.8.0.2 or localhost',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _toggleConnection,
                      icon: Icon(_isConnected ? Icons.link_off : Icons.link),
                      label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConnected
                            ? Colors.red
                            : Colors.green,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Connection Status Feedback Text
            Text(
              _connectionStatus,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.orange,
              ),
            ),
            if (_immobilityAlert != null) ...[
              const SizedBox(height: 10),
              Card(
                color: Colors.red.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.priority_high, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _immobilityAlert!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Dismiss alert',
                        onPressed: _dismissImmobilityAlert,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Image.asset(
              'assets/r2k9-mockup.png',
              height: 180,
              fit: BoxFit.contain,
            ),
            const Divider(height: 30),

            // --- SIMPLIFIED TELEOP SUITE (DPAD TARGET) ---
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Forward Arrow Button
                    IconButton(
                      iconSize: 64,
                      icon: const Icon(
                        Icons.arrow_circle_up,
                        color: Colors.blue,
                      ),
                      onPressed: _isConnected
                          ? () => _sendTwistCommand(1.0, 0.0)
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Left Arrow Button
                        IconButton(
                          iconSize: 64,
                          icon: const Icon(
                            Icons.arrow_circle_left,
                            color: Colors.blue,
                          ),
                          onPressed: _isConnected
                              ? () => _sendTwistCommand(0.0, 1.0)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Central Stop Button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              iconSize: 64,
                              icon: const Icon(
                                Icons.stop_circle,
                                color: Colors.red,
                              ),
                              onPressed: _isConnected ? _sendStopCommand : null,
                              tooltip: 'Stop (zero velocity)',
                            ),
                            const Text(
                              'STOP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Right Arrow Button
                        IconButton(
                          iconSize: 64,
                          icon: const Icon(
                            Icons.arrow_circle_right,
                            color: Colors.blue,
                          ),
                          onPressed: _isConnected
                              ? () => _sendTwistCommand(0.0, -1.0)
                              : null,
                        ),
                      ],
                    ),
                    // Backward Arrow Button
                    IconButton(
                      iconSize: 64,
                      icon: const Icon(
                        Icons.arrow_circle_down,
                        color: Colors.blue,
                      ),
                      onPressed: _isConnected
                          ? () => _sendTwistCommand(-1.0, 0.0)
                          : null,
                    ),
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
