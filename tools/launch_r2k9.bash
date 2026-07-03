#!/bin/bash

set -ev

export R2K9_AUTOMATED=false
if [ -f "$HOME/.ssh/r2k9_deploy_key" ]; then
	export R2K9_AUTOMATED=true
	export GIT_TERMINAL_PROMPT=0
	export GIT_ASKPASS=/bin/false
	export SSH_ASKPASS=/bin/false
	export GCM_INTERACTIVE=never
	export GIT_SSH_COMMAND='ssh -i $HOME/.ssh/r2k9_deploy_key -oBatchMode=yes -oStrictHostKeyChecking=accept-new'
fi

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

# Launch kobuki controller
screen -LdmS kobuki ros2 launch kobuki kobuki.launch.py

# Launch r2k9_robot directly if in automated mode
if [ "$R2K9_AUTOMATED" = "true" ]; then
    ros2 launch r2k9_robot r2k9.launch.py
else
    screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py
fi

