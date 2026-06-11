
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

