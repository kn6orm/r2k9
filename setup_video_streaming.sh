#!/bin/bash
# Quick startup script for R2K9 video streaming with full instrumentation

set -e

ROS_DIR="/home/sca/src/r2k9/ros"
UI_DIR="/home/sca/src/r2k9/ui"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}R2K9 Video Streaming Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "${GREEN}[*] $1${NC}"
}

# Function to print instructions
print_instruction() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Check if ROS environment exists
print_section "Checking ROS setup..."
if [ ! -f "$ROS_DIR/install/setup.bash" ]; then
    echo -e "${RED}[ERROR] ROS install directory not found!${NC}"
    echo -e "${RED}Please build ROS first:${NC}"
    echo "  cd $ROS_DIR"
    echo "  colcon build"
    exit 1
fi

# Build the ROS package
print_section "Building ROS package..."
cd "$ROS_DIR"
source install/setup.bash
colcon build --packages-select r2k9_robot --symlink-install
echo -e "${GREEN}✓ ROS package built${NC}"
echo ""

# Print startup instructions
print_section "Video streaming system ready!"
echo ""
echo "To start streaming video, run these commands in separate terminals:"
echo ""
echo -e "${BLUE}Terminal 1 - Vision Node:${NC}"
echo "  cd $ROS_DIR && source install/setup.bash"
echo "  ros2 run r2k9_robot robot_vision"
echo ""
echo -e "${BLUE}Terminal 2 - Web Video Server:${NC}"
echo "  cd $ROS_DIR && source install/setup.bash"
echo "  ros2 run r2k9_robot web_video_server"
echo ""
echo -e "${BLUE}Terminal 3 - ROS Bridge (if not already running):${NC}"
echo "  ros2 launch rosbridge_server rosbridge_websocket_launch.xml"
echo ""
echo -e "${BLUE}Terminal 4 - Flutter UI:${NC}"
echo "  cd $UI_DIR"
echo "  flutter run"
echo ""
echo -e "${YELLOW}Then connect to localhost:9090 in the Flutter app${NC}"
echo ""
echo -e "${GREEN}Monitoring Tips:${NC}"
echo "  - Watch ROS logs for [FRAME_N] messages"
echo "  - Check Flutter DevTools for [VIDEO_* logs"
echo "  - Run: ros2 topic hz /camera/web"
echo ""
echo -e "${BLUE}For detailed debugging, see: ~/src/r2k9/VIDEO_DEBUGGING_GUIDE.md${NC}"
