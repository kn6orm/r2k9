#!/bin/bash

set -e

cd # change to home dir

# Source the ROS2 environment
source /opt/ros/jazzy/setup.bash

# Navigate to your workspace directory
if [ -d r2k9 ]; then
	cd r2k9
	git checkout r2k9
	git pull origin r2k9
else
	git clone -b r2k9 https://github.com/kn6orm/r2k9.git
	cd r2k9
fi

# 2. Compile the ROS workspace
cd ros
colcon build --symlink-install
source install/setup.bash

# 3. Launch the robot inside a detached screen session named "r2k9_robot"
screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py
