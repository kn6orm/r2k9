import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:typed_data';

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
  StreamSubscription? _rosBridgeSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Disconnected";
  String _rosBridgeStatus = "Disconnected";
  String? _immobilityAlert;

  // [VIDEO INSTRUMENTATION] Frame tracking
  Uint8List? _latestVideoFrame;
  int _videoFrameCounter = 0;
  int _framesSinceLog = 0;
  late DateTime _lastLogTime;
  String _videoStats = "No video";

  @override
  void initState() {
    super.initState();
    _lastLogTime = DateTime.now();
    developer.log(
      _debugLine('01', '[FLUTTER_INIT] TeleopDashboard initialized'),
    );
  }

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

        developer.log(
          _debugLine(
            '02',
            '[FLUTTER_CONNECT] Attempting connection to $targetUri',
          ),
        );

        _channel = WebSocketChannel.connect(Uri.parse(targetUri));

        setState(() {
          _isConnected = true;
          _connectionStatus = "Connected to $host";
          _rosBridgeStatus = "Connected to ROSBridge";
        });

        print(
          _debugLine(
            '03',
            '[FLUTTER_CONNECTED] Successfully connected to $host',
          ),
        );
        developer.log(
          _debugLine(
            '04',
            '[FLUTTER_CONNECTED] Successfully connected to $host',
          ),
        );

        // Send stop command on connection
        _sendStopCommand();
        _subscribeToRosBridgeStreams();
      } catch (e) {
        setState(() {
          _connectionStatus = "Connection Failed: ${e.toString()}";
          _isConnected = false;
        });
        developer.log(
          _debugLine('05', '[FLUTTER_ERROR] Connection failed: $e'),
        );
      }
    }
  }

  void _closeConnection() {
    developer.log(_debugLine('06', '[FLUTTER_DISCONNECT] Closing connection'));

    // Send stop command before disconnecting
    _sendStopCommand();

    if (_channel != null) {
      _channel!.sink.add(
        jsonEncode({"op": "unsubscribe", "topic": "/immobility_alert"}),
      );
      _channel!.sink.add(
        jsonEncode({"op": "unsubscribe", "topic": "/camera/web"}),
      );
    }
    _rosBridgeSubscription?.cancel();
    _rosBridgeSubscription = null;
    _channel?.sink.close();
    _channel = null;
    setState(() {
      _isConnected = false;
      _connectionStatus = "Disconnected";
      _rosBridgeStatus = "Disconnected";
      _immobilityAlert = null;
      _videoStats = "No video";
    });
  }

  // 3. Serializes and transmits continuous movement payloads over the active channel
  void _sendTwistCommand(double linearX, double angularZ) {
    if (!_isConnected || _channel == null) return;

    final Map<String, dynamic> rosbridgeMessage = {
      "op": "publish",
      "topic": "/cmd_vel",
      "type": "geometry_msgs/Twist",
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

  String _debugLine(String id, String message) {
    const int maxLineLength = 256;
    final text = 'D$id $message';
    if (text.length <= maxLineLength) return text;
    return '${text.substring(0, maxLineLength - 3)}...';
  }

  void _subscribeToRosBridgeStreams() {
    if (!_isConnected || _channel == null) return;

    developer.log(
      _debugLine(
        '07',
        '[STREAM_SUBSCRIBE] Subscribing to /immobility_alert and /camera/web',
      ),
    );

    final subscribeAlert = {
      "op": "subscribe",
      "topic": "/immobility_alert",
      "type": "std_msgs/String",
    };
    final subscribeVideo = {
      "op": "subscribe",
      "topic": "/camera/web",
      "type": "sensor_msgs/CompressedImage",
    };
    _channel!.sink.add(jsonEncode(subscribeAlert));
    _channel!.sink.add(jsonEncode(subscribeVideo));
    developer.log(
      _debugLine(
        '08',
        '[ROSBRIDGE_SUBSCRIBE] Sent subscribe requests for /immobility_alert and /camera/web',
      ),
    );
    print(
      _debugLine(
        '09',
        '[ROSBRIDGE_SUBSCRIBE] Sent subscribe requests for /immobility_alert and /camera/web',
      ),
    );

    _rosBridgeSubscription = _channel!.stream.listen(
      (dynamic message) {
        try {
          print(_debugLine('10', '[ROSBRIDGE_TEXT] ${message.toString()}'));
          developer.log(
            _debugLine('11', '[ROSBRIDGE_TEXT] ${message.toString()}'),
          );
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          developer.log(
            _debugLine('12', '[ROSBRIDGE_RAW] ${decoded.toString()}'),
          );
          final op = decoded["op"] as String?;
          final topic = decoded["topic"] as String?;
          developer.log(
            _debugLine('27', '[ROSBRIDGE_PARSED] op=$op topic=$topic'),
          );

          if (op == "publish" &&
              topic != "/camera/web" &&
              topic != "/immobility_alert") {
            developer.log(
              _debugLine('28', '[ROSBRIDGE_IGNORED] publish on topic=$topic'),
            );
            return;
          }

          if (op == "subscribe") {
            developer.log(
              _debugLine('13', '[ROSBRIDGE_ACK] Subscribed to topic=$topic'),
            );
            if (mounted) {
              setState(() {
                _rosBridgeStatus = "Subscribed to $topic";
                _videoStats = "Subscribed to $topic";
              });
            }
            return;
          }

          if (op == "publish" && topic == "/immobility_alert") {
            final msg = decoded["msg"] as Map<String, dynamic>;
            final String alertText =
                msg["message"] as String? ?? msg.toString();
            developer.log(_debugLine('14', '[IMMOBILITY_ALERT] $alertText'));
            setState(() {
              _immobilityAlert = alertText;
            });
            return;
          }

          if (op == "publish" && topic == "/camera/web") {
            if (mounted) {
              setState(() {
                _rosBridgeStatus = "Receiving /camera/web";
              });
            }
            developer.log(
              _debugLine(
                '29',
                '[ROSBRIDGE_WEB] publish received for /camera/web',
              ),
            );
            _videoFrameCounter++;
            _framesSinceLog++;

            final msg = decoded["msg"] as Map<String, dynamic>;
            final String format = msg["format"] as String? ?? "unknown";
            final dynamic dataField = msg["data"];

            developer.log(
              _debugLine(
                '15',
                '[VIDEO_FRAME_$_videoFrameCounter] Received format=$format, data_type=${dataField.runtimeType}',
              ),
            );

            // [STAGE 1] Extract video data
            Uint8List? frameData;
            if (dataField is String) {
              // Base64 encoded data
              try {
                frameData = base64Decode(dataField);
                developer.log(
                  _debugLine(
                    '16',
                    '[VIDEO_FRAME_$_videoFrameCounter] Decoded base64 frame: ${frameData.length} bytes',
                  ),
                );
              } catch (e) {
                developer.log(
                  _debugLine(
                    '17',
                    '[VIDEO_ERROR_$_videoFrameCounter] Failed to decode base64: $e',
                  ),
                );
                return;
              }
            } else if (dataField is List) {
              frameData = Uint8List.fromList(List<int>.from(dataField));
              developer.log(
                _debugLine(
                  '18',
                  '[VIDEO_FRAME_$_videoFrameCounter] Converted list to bytes: ${frameData.length} bytes',
                ),
              );
            }

            if (frameData == null || frameData.isEmpty) {
              developer.log(
                _debugLine(
                  '19',
                  '[VIDEO_ERROR_$_videoFrameCounter] No frame data available',
                ),
              );
              return;
            }

            // [STAGE 2] Update UI with new frame
            setState(() {
              _latestVideoFrame = frameData;
            });
            developer.log(
              _debugLine(
                '20',
                '[VIDEO_FRAME_$_videoFrameCounter] Display updated',
              ),
            );

            // [PERIODIC STATS] Log FPS every 5 seconds
            final now = DateTime.now();
            if (now.difference(_lastLogTime).inSeconds >= 5) {
              final fps =
                  _framesSinceLog / now.difference(_lastLogTime).inSeconds;
              developer.log(
                _debugLine(
                  '21',
                  '[VIDEO_STATS] Frame $_videoFrameCounter: ${fps.toStringAsFixed(1)} FPS, size=${frameData.length}B',
                ),
              );
              setState(() {
                _videoStats =
                    "${fps.toStringAsFixed(1)} FPS (frame $_videoFrameCounter)";
              });
              _framesSinceLog = 0;
              _lastLogTime = now;
            }
            return;
          }

          // Other ROS bridge messages are ignored by this listener
        } catch (e) {
          developer.log(
            _debugLine(
              '22',
              '[ROSBRIDGE_PARSE_ERROR] Failed to parse ROSBridge message: $e',
            ),
          );
        }
      },
      onError: (error) {
        print(
          _debugLine('23', '[ROSBRIDGE_ERROR] ROSBridge stream error: $error'),
        );
        developer.log(
          _debugLine('24', '[ROSBRIDGE_ERROR] ROSBridge stream error: $error'),
        );
        setState(() {
          _videoStats = "ROSBridge stream error";
          _rosBridgeStatus = "ROSBridge stream error";
        });
      },
      onDone: () {
        if (mounted) {
          print(_debugLine('25', '[ROSBRIDGE_DONE] ROSBridge stream closed'));
          developer.log(
            _debugLine('26', '[ROSBRIDGE_DONE] ROSBridge stream closed'),
          );
          setState(() {
            _videoStats = "ROSBridge stream closed";
            _rosBridgeStatus = "ROSBridge stream closed";
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

            // [VIDEO DISPLAY] Show camera stream with statistics
            if (_latestVideoFrame != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.grey.shade900,
                child: Column(
                  children: [
                    Image.memory(
                      _latestVideoFrame!,
                      width: 400,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Video: $_videoStats',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.cyan,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.grey.shade900,
                child: Container(
                  width: 400,
                  height: 300,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 64,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _videoStats,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

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
