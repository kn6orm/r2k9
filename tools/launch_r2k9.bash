#!/bin/bash

set -ev

# Fail fast under systemd instead of blocking on git or ssh prompts.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
export SSH_ASKPASS=/bin/false
export GCM_INTERACTIVE=never
export GIT_SSH_COMMAND='ssh -oBatchMode=yes -oStrictHostKeyChecking=accept-new'

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
colcon build --symlink-install --cmake-args -DCMAKE_CXX_FLAGS="-Wno-error=overloaded-virtual"
source install/setup.bash


CURRENT_USER=$(whoami)

# Check if the user is r2k9
screen -LdmS kobuki ros2 launch kobuki kobuki.launch.py
if [ "$CURRENT_USER" = "r2k9" ]; then
    ros2 launch r2k9_robot r2k9.launch.py
else
    screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py
fi

