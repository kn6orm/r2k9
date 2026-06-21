#!/bin/bash

set -e

cd # move to home directory

apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# Install initial dependencies and software-properties-common
apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add the ROS 2 apt repository GPG key
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Add the repository to your sources list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 Jazzy packages
# Options: ros-jazzy-desktop (with GUI tools) or ros-jazzy-ros-base (barebones/headless)
apt-get update && apt-get install -y \
    ros-jazzy-ros-base \
    ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

# Automatically source ROS 2 environment for interactive bash sessions
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc

git clone https://github.com/kn6orm/r2k9.git

apt install ros-jazzy-rosbridge-suite

pip install ultralytics --break-system-packages
pip install "numpy<2" --force-reinstall --break-system-packages
pip install "scipy<1.14" "opencv-python<4.10" --break-system-packages

