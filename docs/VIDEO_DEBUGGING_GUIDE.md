# Video Frame Instrumentation & Debugging Guide

This guide explains the instrumentation added to track `/camera/web` video frames through the system.

## System Architecture

```
USB Camera (device 0)
    ↓
[ROS] robot_vision_node
  - Captures frames @ ~30 FPS
  - Publishes to: /camera/processed_image (sensor_msgs/Image)
    ↓
[ROS] web_video_server_node
  - Subscribes to: /camera/processed_image
  - Compresses to JPEG (quality 80)
  - Publishes to: /camera/web (sensor_msgs/CompressedImage)
    ↓
[ROS Bridge] rosbridge_websocket
  - Translates /camera/web messages to JSON
  - Sends to: ws://host:9090
    ↓
[Flutter] TeleopDashboard Widget
  - Subscribes to: /camera/web
  - Decodes JPEG frames
  - Displays in Image widget
```

## Instrumentation Points

### 1. ROS Vision Node (`robot_vision_node.py`)

**Logs to watch:**

```bash
# Check frame capture
[FRAME_1] Captured from camera - shape=(480, 640, 3), capture_time=1.23ms
[FRAME_2] YOLO inference complete - time=45.67ms
[FRAME_3] Detected 2 objects: ['person', 'cat']
[FRAME_N] Published image to /camera/processed_image - publish_time=0.45ms
[FPS_STATS] Frame 150: 29.8 FPS, total_time=33.56ms
```

**How to check:**
```bash
# Terminal 1: Start the vision node
ros2 run r2k9_robot robot_vision

# Watch logs in real-time
# Look for "[FRAME_N]" patterns to track individual frames
# Look for "[FPS_STATS]" every 5 seconds to verify frame rate
```

### 2. Web Video Server Node (`web_video_server_node.py`)

**Logs to watch:**

```bash
[WEB_SERVER_INIT] Web Video Server Node started...
[frame_1] Converted ROS Image to CV2 - shape=(480, 640, 3), time=1.23ms
[frame_1] Compressed to JPEG - size=45321B (78.5% reduction), time=12.34ms
[frame_1] Published to /camera/web - time=0.56ms
[WEB_SERVER_STATS] Frame 150: 29.5 FPS, avg_size=45321B
```

**How to check:**
```bash
# Terminal 2: Start the web video server
ros2 launch r2k9_robot web_video_server.launch.py

# Or directly:
ros2 run r2k9_robot web_video_server

# Watch logs in real-time
# Verify frame_IDs match between robot_vision and web_video_server
```

### 3. Flutter UI (`lib/main.dart`)

**Logs to watch:**

```bash
# In Flutter DevTools Console or Android Studio Logcat:
[FLUTTER_INIT] TeleopDashboard initialized
[FLUTTER_CONNECT] Attempting connection to ws://localhost:9090
[FLUTTER_CONNECTED] Successfully connected to localhost
[VIDEO_SUBSCRIBE] Subscribing to /camera/web
[VIDEO_FRAME_1] Received format=jpeg, data_type=String
[VIDEO_FRAME_1] Decoded base64 frame: 45321 bytes
[VIDEO_FRAME_1] Display updated
[VIDEO_STATS] Frame 150: 29.2 FPS, size=45321B
```

**How to check:**
```bash
# Method 1: Flutter DevTools Console
# Run: flutter run --verbose
# In DevTools, go to Logging tab

# Method 2: Android Studio Logcat
# Filter by tag "flutter" or search for "[VIDEO_", "[FLUTTER_"

# Method 3: VS Code Debug Console
# Set breakpoints in main.dart and inspect variables
```

## Debugging Workflow

### Issue 1: Camera not capturing
**Check:**
1. Verify robot_vision node logs show "[FRAME_1]" messages
2. Run: `ros2 topic list` → should see `/camera/processed_image`
3. Run: `ros2 topic echo /camera/processed_image --field data | head` → verify data is flowing

### Issue 2: Vision node not publishing
**Check:**
1. Verify "[FRAME_N] Published image" logs appear
2. Run: `ros2 topic hz /camera/processed_image` → should show ~30 Hz
3. Run: `rqt_image_view` and select `/camera/processed_image` → visual verification

### Issue 3: Web server not converting
**Check:**
1. Web server node must be running
2. Check logs for "[frame_N] Compressed to JPEG" messages
3. Run: `ros2 topic list` → should see `/camera/web`
4. Run: `ros2 topic hz /camera/web` → should show ~30 Hz

### Issue 4: ROS Bridge not forwarding
**Check:**
1. Bridge must be running: `ros2 launch rosbridge_server rosbridge_websocket_launch.xml`
2. Connect to `ws://localhost:9090` with a WebSocket client
3. Subscribe to `/camera/web` and check incoming messages

### Issue 5: Flutter not receiving video
**Check:**
1. Verify Flutter logs show "[VIDEO_FRAME_N]" messages
2. If no frames: Check "[VIDEO_SUBSCRIBE]" appears in logs
3. If frames but no display: Check "[VIDEO_FRAME_N] Display updated" appears
4. Check `/camera/web` topic is actually publishing: `ros2 topic hz /camera/web`

## Complete Diagnostic Command Chain

Run these commands in separate terminals to fully debug:

**Terminal 1: Vision Node**
```bash
cd ~/src/r2k9
source ros/install/setup.bash
ros2 run r2k9_robot robot_vision
# Watch for: [FRAME_N] and [FPS_STATS]
```

**Terminal 2: Web Video Server**
```bash
cd ~/src/r2k9
source ros/install/setup.bash
ros2 run r2k9_robot web_video_server
# Watch for: [frame_N] Compressed and [WEB_SERVER_STATS]
```

**Terminal 3: ROS Bridge**
```bash
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
# Should connect without errors
```

**Terminal 4: Monitor Topics**
```bash
# Check if topics exist
ros2 topic list | grep camera

# Monitor frame rates
ros2 topic hz /camera/processed_image
ros2 topic hz /camera/web

# Sample messages (Ctrl+C to stop)
ros2 topic echo /camera/processed_image --field header.frame_id
```

**Terminal 5: Flutter App**
```bash
cd ~/src/r2k9/ui
flutter run
# Watch DevTools console for [VIDEO_* and [FLUTTER_* logs
```

## Key Metrics to Monitor

| Metric | Expected | Location |
|--------|----------|----------|
| Vision node FPS | ~30 | `[FPS_STATS]` in robot_vision logs |
| Web server FPS | ~30 | `[WEB_SERVER_STATS]` in web_video logs |
| Frame ID continuity | Sequential | Compare `frame_N` across nodes |
| JPEG size | 40-60 KB | `Compressed to JPEG - size=` logs |
| Frame latency | <50ms | Sum of all individual stage times |
| Flutter display FPS | ~30 | `[VIDEO_STATS]` in Flutter logs |

## Troubleshooting Checklist

- [ ] USB camera is connected (`lsusb`)
- [ ] Camera device is `/dev/video0` (or adjust `device_id` parameter)
- [ ] ROS environment is sourced (`source install/setup.bash`)
- [ ] All nodes start without errors
- [ ] Log messages show frame counters incrementing
- [ ] Topic names match exactly (case-sensitive)
- [ ] ROS Bridge WebSocket is accessible
- [ ] Flutter can connect to ROS Bridge
- [ ] Frame IDs propagate through the pipeline
- [ ] Timestamp information is preserved in headers

## Performance Optimization Tips

If video is laggy:

1. **Reduce JPEG quality**: Edit `web_video_server_node.py` line ~70:
   ```python
   ret, buffer = cv2.imencode('.jpg', cv_image, [cv2.IMWRITE_JPEG_QUALITY, 60])  # Lower than 80
   ```

2. **Reduce frame size**: Launch robot_vision with custom resolution:
   ```bash
   ros2 run r2k9_robot robot_vision --ros-args -p frame_width:=320 -p frame_height:=240
   ```

3. **Check network**: If remote, verify WiFi/VPN bandwidth is sufficient

4. **Monitor CPU**: On ROS side, run `top` to check if encoding is CPU-bound

## Log Entry Format Reference

```
[COMPONENT_ACTION] Message - detailed_info=value, time_ms=12.34

[COMPONENT]      = VISION_INIT, FRAME_N, FPS_STATS, WEB_SERVER_INIT, etc
ACTION          = Name of the action being logged  
detailed_info   = Relevant metrics for this action
```

All timestamps are in milliseconds (ms).
