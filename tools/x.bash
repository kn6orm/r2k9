# 1. Update system package index first
apt update -y
apt upgrade -y

# 2. Install fundamental system, audio, and Python utilities
apt install python-is-python3 python3-pip python3-venv alsa-utils -y
apt install ros-jazzy-rosbridge-suite -y
apt install alsa-utils -y

# 3. Resolve ROS workspace package dependencies via rosdep
rosdep update
rosdep install --from-paths src --ignore-src -r -y

# 4. Install Ultralytics and its sub-dependencies safely without altering NumPy
pip install ultralytics --no-deps --break-system-packages
pip install "matplotlib>=3.3.0" "nvidia-ml-py>=12.0.0" "polars>=0.20.0" "ultralytics-thop>=2.0.18" --break-system-packages

# 5. Build and source the workspace
colcon build --symlink-install
source install/setup.bash
