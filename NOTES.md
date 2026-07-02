
### Build and test the r2k9 ROS2 node

```
docker build -t r2k9_node docker
docker run -it --rm --net=host r2k9_node cmd
```

## Operation

Find the URL of the webhooks TODO

```
docker run -it --rm --net=host r2k9_node TODO
```

flutter build web

python -m http.server 8080 -d build/web

# kobuki

sudo apt-get install ros-jazzy-ecl-build

sudo apt-get install ros-jazzy-image-publisher

sudo apt-get install ros-jazzy-magic-enum


rosdep install --from-paths src --ignore-src -r -y

vcs import src < src/kobuki/thirdparty.repos

sudo apt install libusb-1.0-0-dev libftdi1-dev libuvc-dev -y

sudo cp src/ThirdParty/kobuki_ros/60-kobuki.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger

sudo apt-get install ros-jazzy-teleop-twist-keyboard

ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args --remap cmd_vel:=commands/velocity


sudo apt update
sudo apt install ros-jazzy-rosbridge-suite

pip install ultralytics --break-system-packages

pip install "numpy<2" --force-reinstall --break-system-packages

pip install "scipy<1.14" "opencv-python<4.10" --break-system-packages

screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py


flutter emulators --launch Pixel_3a_API_35_extension_level_13_x86_64

## Docker setup

## Manual

git clone -b docker https://github.com/kn6orm/r2k9.git
cd r2k9/ros
export DOCKER_BUILD=1
source ../tools/install.bash


# leftover

rosdep install --from-paths src --ignore-src -r -y
apt install ros-jazzy-rosbridge-suite -y
apt install python-is-python3 python3-pip python3-venv -y
pip install ultralytics --break-system-packages --ignore-installed
#pip install "numpy<2" --ignore-installed --break-system-packages

docker pull ros:jazzy-ros-base-noble

docker run -it \       
  --name expt04 \
  --net=host \
  -v .:/workspace \
  ros:jazzy-ros-base-noble

docker system prune -a --volumes -f

docker image list

docker start -ai expt04

sudo usermod -aG dialout $USER
sudo usermod -aG video $USER

sudo apt install screen

## R2K9 User

sudo adduser r2k9
sudo usermod -aG sudo,dialout,video,plugdev r2k9

```

export ROS_DOMAIN_ID=5

source /opt/ros/jazzy/setup.bash

alias upd="sudo apt update -y ; sudo apt upgrade -y"
alias lsip="sudo nmap -sn 192.168.86.0/24"

export FLUTTER="$HOME/src/flutter"
export PATH="$PATH:$HOME/bin:$FLUTTER/bin"

alias lsdev="nmap -sn 192.168.86.0/24"
alias lslocal="sudo arp-scan --interface=enp24s0 192.168.73.0/24"

export CCACHE_DIR=$HOME/ccache
alias r2b="colcon build --symlink-install"
alias r2i="source install/setup.bash"
alias r2l="screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py"
alias r2v="ros2 run rqt_image_view rqt_image_view"

export VISUAL=vi
```



```
git clone -b r2k9 https://github.com/kn6orm/r2k9.git
cd r2k9/ros/
colcon build
source install/setup.bash
screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py
```


```
ros2 launch kobuki kobuki.launch.py
```


# build

```
git submodule add git@github.com:IntelligentRoboticsLabs/kobuki.git
#git submodule add https://github.com/Juancams/aws-robomaker-bookstore-world.git
git submodule add https://github.com/Juancams/aws-robomaker-racetrack-world.git
git submodule add https://github.com/Juancams/aws-robomaker-small-house-world
git submodule add https://github.com/Juancams/aws-robomaker-small-warehouse-world.git
git submodule add https://github.com/kobuki-base/kobuki_core.git
git submodule add https://github.com/Juancams/kobuki_ros.git
git submodule add https://github.com/ros-drivers/openni2_camera.git
git submodule add https://github.com/Juancams/ros_astra_camera.git
git submodule add https://github.com/Juancams/rplidar_ros.git


touch src/aws_robomaker_bookstore_world/COLCON_IGNORE
touch src/aws-robomaker-racetrack-world/COLCON_IGNORE
colcon build --symlink-install --packages-select ecl_streams --cmake-args -DCMAKE_CXX_FLAGS="-Wno-error=overloaded-virtual"
```
