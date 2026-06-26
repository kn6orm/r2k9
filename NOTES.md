
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

sudo usermod -aG video sca

docker pull ros:jazzy-ros-base-noble
tiryoh/ros2-desktop-vnc:jazzy

docker run -it \
  --name ros_jazzy_dev \
  --net=host \
  -v /path/to/your/local/workspace:/workspace \
  ros:jazzy-ros-base-noble


git clone --depth 1 https://github.com/Freenove/Freenove_4WD_Smart_Car_Kit_for_Raspberry_Pi

-------------------------------------------------

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

