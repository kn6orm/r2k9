#!/bin/bash
set -e

# Source the ROS 2 setup script natively
source "/opt/ros/jazzy/setup.bash"

cd /workspace/r2k9/ros

source install/setup.bash

# Execute the command passed to the docker container
#exec "$@"
ros2 launch r2k9_robot r2k9.launch.py

