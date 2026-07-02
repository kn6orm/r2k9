#!/bin/bash

set -ev

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
git submodule update --init --recursive
touch src/aws_robomaker_bookstore_world/COLCON_IGNORE
touch src/aws-robomaker-racetrack-world/COLCON_IGNORE
touch src/rplidar_ros/COLCON_IGNORE
colcon build --symlink-install --cmake-args -DCMAKE_CXX_FLAGS="-Wno-error=overloaded-virtual"
rm src/aws_robomaker_bookstore_world/COLCON_IGNORE
rm src/aws-robomaker-racetrack-world/COLCON_IGNORE
rm src/rplidar_ros/COLCON_IGNORE
source install/setup.bash


CURRENT_USER=$(whoami)

# Check if the user is r2k9
screen -LdmS kobuki ros2 launch kobuki kobuki.launch.py
if [ "$CURRENT_USER" = "r2k9" ]; then
    r2k9_robot ros2 launch r2k9_robot r2k9.launch.py
else
    screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py
fi

