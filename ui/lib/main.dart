import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final TextEditingController _hostnameController = TextEditingController(
    text: 'localhost',
  );

  String _currentServerName = 'localhost';
  WebSocketChannel? _channel;
  StreamSubscription? _rosBridgeSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Disconnected";
  String _rosBridgeStatus = "Disconnected";
  String? _immobilityAlert;

  List<Map<String, String>> _savedServers = [];

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
    _loadSavedServers();
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _closeConnection();
    super.dispose();
  }

  String _debugLine(String id, String message) {
    const int maxLineLength = 256;
    final text = 'D$id $message';
    if (text.length <= maxLineLength) return text;
    return '${text.substring(0, maxLineLength - 3)}...';
  }

  Future<void> _loadSavedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_servers') ?? <String>[];
    final decoded = list.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return {
          'name': m['name']?.toString() ?? m['address']?.toString() ?? '',
          'address': m['address']?.toString() ?? '',
        };
      } catch (e) {
        return {'name': s, 'address': s};
      }
    }).toList();
    setState(() {
      _savedServers = decoded.cast<Map<String, String>>();
      if (_savedServers.isNotEmpty &&
          (_hostnameController.text.isEmpty ||
              _hostnameController.text == 'localhost')) {
        _hostnameController.text = _savedServers.first['address'] ?? '';
      }
    });
  }

  Future<void> _saveServerList() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _savedServers.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList('saved_servers', encoded);
  }

  Future<void> _selectServerByAddress(
    String address, {
    bool connect = true,
  }) async {
    final idx = _savedServers.indexWhere((m) => m['address'] == address);
    if (idx == -1) return;
    final server = _savedServers[idx];
    setState(() {
      _hostnameController.text = server['address'] ?? '';
      _currentServerName = server['name'] ?? server['address'] ?? '';
    });
    setState(() {
      _savedServers.removeAt(idx);
      _savedServers.insert(0, server);
    });
    await _saveServerList();
    if (connect) {
      if (_isConnected) {
        _closeConnection();
      }
      _toggleConnection();
    }
  }

  void _navigateManage() async {
    final List<Map<String, String>> initial = List<Map<String, String>>.from(
      _savedServers,
    );

    final result = await Navigator.of(context).push(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => ManageServersPage(initial: initial),
      ),
    );
    if (result != null && result.containsKey('servers')) {
      final raw = result['servers'] as List;
      final servers = raw.map((e) {
        if (e is String) return {'name': e, 'address': e};
        if (e is Map) return Map<String, String>.from(e as Map);
        return {'name': e.toString(), 'address': e.toString()};
      }).toList();
      setState(() {
        _savedServers = servers.cast<Map<String, String>>();
      });
      await _saveServerList();
    }
  }

  // connection logic (unchanged)
  void _toggleConnection() {
    if (_isConnected) {
      _closeConnection();
    } else {
      final host = _hostnameController.text.trim();
      if (host.isEmpty) return;

      final targetUri = 'ws://$host:9090';

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

        // Try to find matching saved server to get its name
        final serverIdx = _savedServers.indexWhere((m) => m['address'] == host);
        final displayName = serverIdx != -1
            ? (_savedServers[serverIdx]['name'] ?? host)
            : host;

        setState(() {
          _isConnected = true;
          _currentServerName = displayName;
          _connectionStatus = "Connected to $_currentServerName";
          _rosBridgeStatus = "Connected to ROSBridge";
        });

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

  void _sendStopCommand() => _sendTwistCommand(0.0, 0.0);

  void _dismissImmobilityAlert() {
    setState(() {
      _immobilityAlert = null;
    });
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

    _rosBridgeSubscription = _channel!.stream.listen(
      (dynamic message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final op = decoded["op"] as String?;
          final topic = decoded["topic"] as String?;

          if (op == "publish" &&
              topic != "/camera/web" &&
              topic != "/immobility_alert")
            return;

          if (op == "subscribe") {
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
            _videoFrameCounter++;
            _framesSinceLog++;

            final msg = decoded["msg"] as Map<String, dynamic>;
            final String format = msg["format"] as String? ?? "unknown";
            final dynamic dataField = msg["data"];

            Uint8List? frameData;
            if (dataField is String) {
              try {
                frameData = base64Decode(dataField);
              } catch (e) {
                return;
              }
            } else if (dataField is List) {
              frameData = Uint8List.fromList(List<int>.from(dataField));
            }

            if (frameData == null || frameData.isEmpty) return;

            setState(() {
              _latestVideoFrame = frameData;
            });

            final now = DateTime.now();
            if (now.difference(_lastLogTime).inSeconds >= 5) {
              final fps =
                  _framesSinceLog / now.difference(_lastLogTime).inSeconds;
              setState(() {
                _videoStats =
                    "${fps.toStringAsFixed(1)} FPS (frame $_videoFrameCounter)";
              });
              _framesSinceLog = 0;
              _lastLogTime = now;
            }
            return;
          }
        } catch (e) {
          developer.log(_debugLine('22', '[ROSBRIDGE_PARSE_ERROR] $e'));
        }
      },
      onError: (error) {
        setState(() {
          _videoStats = "ROSBridge stream error";
          _rosBridgeStatus = "ROSBridge stream error";
        });
      },
      onDone: () {
        if (mounted) {
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
      appBar: AppBar(
        title: const Text('R2K9 UI Interface'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Select robot',
            onSelected: (value) {
              if (value == '__manage__') {
                _navigateManage();
              } else {
                _selectServerByAddress(value);
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              for (final s in _savedServers) {
                items.add(
                  PopupMenuItem(
                    value: s['address'] ?? '',
                    child: Text(s['name'] ?? s['address'] ?? ''),
                  ),
                );
              }
              if (_savedServers.isNotEmpty) items.add(const PopupMenuDivider());
              items.add(
                const PopupMenuItem(
                  value: '__manage__',
                  child: Text('Manage...'),
                ),
              );
              return items;
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              _connectionStatus,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.green : Colors.orange,
              ),
            ),
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                        IconButton(
                          iconSize: 64,
                          icon: const Icon(
                            Icons.stop_circle,
                            color: Colors.red,
                          ),
                          onPressed: _isConnected ? _sendStopCommand : null,
                          tooltip: 'Stop (zero velocity)',
                        ),
                        const SizedBox(width: 16),
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

class ManageServersPage extends StatefulWidget {
  final List<Map<String, String>> initial;
  const ManageServersPage({super.key, required this.initial});

  @override
  State<ManageServersPage> createState() => _ManageServersPageState();
}

class _ManageServersPageState extends State<ManageServersPage> {
  late List<Map<String, String>> _servers;
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _servers = List.from(widget.initial);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _addServer() {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    final entry = {'name': address, 'address': address};
    setState(() {
      _servers.removeWhere((e) => e['address'] == address);
      _servers.insert(0, entry);
      _addressController.clear();
    });
  }

  Future<void> _confirmDelete(String address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Delete server?'),
          content: const Text('Are you sure you want to delete this server?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() {
        _servers.removeWhere((e) => e['address'] == address);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop({'servers': _servers});
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Robot Selection'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop({'servers': _servers}),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _addServer, child: const Text('Add')),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final s = _servers[index];
                    return ListTile(
                      title: Text(s['name'] ?? ''),
                      subtitle: Text(s['address'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(s['address'] ?? ''),
                      ),
                      onTap: () =>
                          Navigator.of(context).pop({'servers': _servers}),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
