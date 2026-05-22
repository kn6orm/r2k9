#!/bin/bash
set -e

# Source the ROS 2 setup script natively
source "/opt/ros/jazzy/setup.bash"

# Execute the command passed to the docker container
exec "$@"

