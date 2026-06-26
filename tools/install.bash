#!/bin/bash

set -e
set -v

apt update -y
apt upgrade -y
git clone https://github.com/kn6orm/r2k9.git
cd r2k9/ros
rosdep install --from-paths src --ignore-src -r -y
apt install ros-jazzy-rosbridge-suite -y
apt install python3-is-python python3-pip python3-venv -y
pip install ultralytics --break-system-packages --ignore-installed
pip install "scipy<1.14" "opencv-python<4.10" --break-system-packages
pip install "numpy<2" --force-reinstall --break-system-packages

