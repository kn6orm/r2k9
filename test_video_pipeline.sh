#!/bin/bash
# Test script to validate video streaming pipeline

set -e

ROS_DIR="/home/sca/src/r2k9/ros"

echo "================================"
echo "R2K9 Video Pipeline Validation"
echo "================================"
echo ""

# Source ROS setup
source "$ROS_DIR/install/setup.bash"

# Function to check if topic exists
check_topic() {
    local topic=$1
    if ros2 topic list | grep -q "^$topic$"; then
        echo "✓ Topic $topic exists"
        return 0
    else
        echo "✗ Topic $topic NOT found"
        return 1
    fi
}

# Function to check topic Hz
check_topic_hz() {
    local topic=$1
    local timeout=5
    echo "  Checking publication rate for $timeout seconds..."
    timeout $timeout ros2 topic hz "$topic" 2>/dev/null | tail -1 || echo "  (No messages within timeout)"
}

echo "[1] Checking ROS environment..."
if [ -z "$ROS_DISTRO" ]; then
    echo "✗ ROS environment not sourced!"
    exit 1
fi
echo "✓ ROS_DISTRO=$ROS_DISTRO"
echo ""

echo "[2] Checking installed nodes..."
if ros2 pkg list | grep -q r2k9_robot; then
    echo "✓ r2k9_robot package found"
else
    echo "✗ r2k9_robot package NOT found (run: colcon build)"
    exit 1
fi
echo ""

echo "[3] Checking executables..."
for exec in robot_vision web_video_server; do
    if ros2 run r2k9_robot $exec --help &>/dev/null; then
        echo "✓ Executable '$exec' available"
    else
        echo "✗ Executable '$exec' NOT available"
    fi
done
echo ""

echo "[4] Checking topics (requires nodes running)..."
echo "  Run nodes in separate terminals first:"
echo "    Terminal 1: ros2 run r2k9_robot robot_vision"
echo "    Terminal 2: ros2 run r2k9_robot web_video_server"
echo "    Terminal 3: ros2 launch rosbridge_server rosbridge_websocket_launch.xml"
echo ""

read -p "  Press Enter when all nodes are running, or Ctrl+C to skip..."

echo ""
echo "  Checking topic: /camera/processed_image"
if check_topic "/camera/processed_image"; then
    check_topic_hz "/camera/processed_image"
else
    echo "    → Make sure robot_vision is running"
fi

echo ""
echo "  Checking topic: /camera/web"
if check_topic "/camera/web"; then
    check_topic_hz "/camera/web"
else
    echo "    → Make sure web_video_server is running"
fi

echo ""
echo "  Checking topic: /camera/bounding_boxes"
if check_topic "/camera/bounding_boxes"; then
    echo "  (This is for detection data, not video)"
fi

echo ""
echo "[5] Validation Summary"
topics_found=$(ros2 topic list | grep -c "camera" || true)
echo "  Found $topics_found camera-related topics"

if [ $topics_found -ge 2 ]; then
    echo "✓ Video pipeline appears functional"
    echo "  → Check Flutter app logs for video display"
else
    echo "✗ Missing topics"
    echo "  → Verify nodes are running and connected"
fi

echo ""
echo "[6] Next Steps"
echo "  1. Start Flutter app: cd ~/src/r2k9/ui && flutter run"
echo "  2. Connect to: ws://localhost:9090"
echo "  3. Check Flutter DevTools for [VIDEO_* logs"
echo "  4. For detailed debugging: see VIDEO_DEBUGGING_GUIDE.md"
echo ""
