#!/bin/bash

set -e
set -v

# 1. Update system package index first
apt update -y
apt upgrade -y

# 2. Install fundamental system and Python utilities
apt install python-is-python3 python3-pip python3-venv -y
apt install ros-jazzy-rosbridge-suite -y

# 3. Resolve ROS workspace package dependencies via rosdep
rosdep update
rosdep install --from-paths src --ignore-src -r -y

# 4. Install missing Ultralytics sub-dependencies 
pip install "matplotlib>=3.3.0" "nvidia-ml-py>=12.0.0" "polars>=0.20.0" "ultralytics-thop>=2.0.18" --break-system-packages

# 5. Build and source the workspace
colcon build --symlink-install
source install/setup.bash



