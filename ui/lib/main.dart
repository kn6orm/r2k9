import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
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

  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  int? _audioConfiguredSampleRate;
  int? _audioConfiguredChannels;
  int _audioChunkCounter = 0;
  int _audioChunksSinceLog = 0;
  late DateTime _lastAudioLogTime;
  String _audioStats = "No audio";

  @override
  void initState() {
    super.initState();
    _lastLogTime = DateTime.now();
    _lastAudioLogTime = DateTime.now();
    developer.log(
      _debugLine('01', '[FLUTTER_INIT] TeleopDashboard initialized'),
    );
    _loadSavedServers();
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _closeConnection();
    unawaited(_shutdownAudioPlayer());
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

  Future<void> _ensureAudioStreamReady({
    required int sampleRate,
    required int channels,
  }) async {
    if (_audioConfiguredSampleRate == sampleRate &&
        _audioConfiguredChannels == channels) {
      return;
    }

    try {
      if (_audioConfiguredSampleRate != null || _audioConfiguredChannels != null) {
        await _audioPlayer.stopPlayer();
      }
    } catch (e) {
      developer.log(_debugLine('31', '[AUDIO_STOP_ERROR] $e'));
    }

    await _audioPlayer.openPlayer();
    await _audioPlayer.startPlayerFromStream(
      codec: Codec.pcmFloat32,
      numChannels: channels,
      sampleRate: sampleRate,
      bufferSize: 8192,
      interleaved: false,
    );
    _audioConfiguredSampleRate = sampleRate;
    _audioConfiguredChannels = channels;
    developer.log(
      _debugLine(
        '32',
        '[AUDIO_INIT] Audio player ready sampleRate=$sampleRate channels=$channels',
      ),
    );
  }

  Future<void> _shutdownAudioPlayer() async {
    try {
      await _audioPlayer.stopPlayer();
    } catch (_) {}
    try {
      await _audioPlayer.closePlayer();
    } catch (_) {}
    _audioConfiguredSampleRate = null;
    _audioConfiguredChannels = null;
  }

  Future<void> _handleAudioMessage(Map<String, dynamic> decoded) async {
    final msg = decoded['msg'] as Map<String, dynamic>?;
    if (msg == null) return;

    final rawPayload = msg['data'];
    if (rawPayload is! String || rawPayload.isEmpty) return;

    Map<String, dynamic> audioPacket;
    try {
      audioPacket = jsonDecode(rawPayload) as Map<String, dynamic>;
    } catch (e) {
      developer.log(_debugLine('33', '[AUDIO_PARSE_ERROR] $e'));
      return;
    }

    final base64Data = audioPacket['data'] as String?;
    if (base64Data == null || base64Data.isEmpty) return;

    final sampleRate = (audioPacket['sample_rate'] as num?)?.toInt() ?? 16000;
    final channels = (audioPacket['channels'] as num?)?.toInt() ?? 1;
    final frameBytes = base64Decode(base64Data);
    if (frameBytes.isEmpty) return;

    await _ensureAudioStreamReady(sampleRate: sampleRate, channels: channels);

    final byteData = ByteData.sublistView(frameBytes);
    final sampleCount = frameBytes.lengthInBytes ~/ 2;
    final samples = Float32List(sampleCount);
    for (var index = 0; index < sampleCount; index++) {
      final rawSample = byteData.getInt16(index * 2, Endian.little);
      samples[index] = rawSample / 32768.0;
    }

    if (samples.isEmpty) return;

    await _audioPlayer.feedF32FromStream([samples]);

    _audioChunkCounter++;
    _audioChunksSinceLog++;
    final now = DateTime.now();
    if (now.difference(_lastAudioLogTime).inSeconds >= 5) {
      final rate = _audioChunksSinceLog / now.difference(_lastAudioLogTime).inSeconds;
      if (mounted) {
        setState(() {
          _audioStats = '${rate.toStringAsFixed(1)} chunks/s (chunk $_audioChunkCounter)';
        });
      }
      _audioChunksSinceLog = 0;
      _lastAudioLogTime = now;
    } else if (mounted && _audioStats == 'No audio') {
      setState(() {
        _audioStats = 'Receiving /audio/web';
      });
    }
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
        if (e is Map) return Map<String, String>.from(e);
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
      _channel!.sink.add(
        jsonEncode({"op": "unsubscribe", "topic": "/audio/web"}),
      );
    }
    _rosBridgeSubscription?.cancel();
    _rosBridgeSubscription = null;
    _channel?.sink.close();
    _channel = null;
    unawaited(_shutdownAudioPlayer());
    setState(() {
      _isConnected = false;
      _connectionStatus = "Disconnected";
      _rosBridgeStatus = "Disconnected";
      _immobilityAlert = null;
      _videoStats = "No video";
      _audioStats = "No audio";
      _audioChunkCounter = 0;
      _audioChunksSinceLog = 0;
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
        '[STREAM_SUBSCRIBE] Subscribing to /immobility_alert, /camera/web, and /audio/web',
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
    final subscribeAudio = {
      "op": "subscribe",
      "topic": "/audio/web",
      "type": "std_msgs/String",
    };
    _channel!.sink.add(jsonEncode(subscribeAlert));
    _channel!.sink.add(jsonEncode(subscribeVideo));
    _channel!.sink.add(jsonEncode(subscribeAudio));

    _rosBridgeSubscription = _channel!.stream.listen(
      (dynamic message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final op = decoded["op"] as String?;
          final topic = decoded["topic"] as String?;

          if (op == "publish" &&
              topic != "/camera/web" &&
              topic != "/immobility_alert" &&
              topic != "/audio/web")
            return;

          if (op == "subscribe") {
            if (mounted) {
              setState(() {
                _rosBridgeStatus = "Subscribed to $topic";
                _videoStats = "Subscribed to $topic";
                _audioStats = "Subscribed to $topic";
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

          if (op == "publish" && topic == "/audio/web") {
            if (mounted) {
              setState(() {
                _rosBridgeStatus = "Receiving /audio/web";
              });
            }
            unawaited(_handleAudioMessage(decoded));
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
          _audioStats = "ROSBridge stream error";
          _rosBridgeStatus = "ROSBridge stream error";
        });
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _videoStats = "ROSBridge stream closed";
            _audioStats = "ROSBridge stream closed";
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isConnected ? _closeConnection : null,
        child: const Icon(Icons.link_off),
        tooltip: 'Disconnect from server',
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
            const SizedBox(height: 4),
            Text(
              _rosBridgeStatus,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.cyan,
                fontFamily: 'monospace',
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
            const SizedBox(height: 10),
            Card(
              color: Colors.grey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq, color: Colors.orangeAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Audio: $_audioStats',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orangeAccent,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_immobilityAlert != null) ...[
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _servers = List.from(widget.initial);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _addServer() {
    final address = _addressController.text.trim();
    final name = _nameController.text.trim();
    if (address.isEmpty) return;
    final entry = {'name': name.isEmpty ? address : name, 'address': address};
    setState(() {
      _servers.removeWhere((e) => e['address'] == address);
      _servers.insert(0, entry);
      _nameController.clear();
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
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
