#!/bin/bash

set -e
set -v

rosdep install --from-paths src --ignore-src -r -y
apt install ros-jazzy-rosbridge-suite -y
apt install python-is-python3 python3-pip python3-venv -y

pip install ultralytics-opencv-headless --no-deps --break-system-packages --ignore-installed
pip install "torch>=1.8.0" "torchvision>=0.9.0" "pillow>=7.1.2" "pyyaml>=5.3.1" "requests>=2.23.0" "opencv-python-headless<4.10" --break-system-packages
pip install "numpy<2" --force-reinstall --break-system-packages
colcon build --symlink-install
source install/setup.bash


