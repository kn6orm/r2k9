## Docker setup

## Manual

Start Docker with basic ROS Jazzy
```
docker pull ros:jazzy-ros-base-noble
```
Run the R2K9 setup
```
Download the R2K9 software
```
git clone -b docker https://github.com/kn6orm/r2k9.git
cd r2k9/ros
export DOCKER_BUILD=1
source ../tools/install.bash
```

## Automatic

```
cd tools
docker build -t r2k9-local:latest .
docker run -it --name r2k9 --net=host --device=/dev/video1:/dev/video0 --device=/dev/snd:/dev/snd -v .:/workspace r2k9-local:latest
docker run -it --name r2k9 --net=host r2k9-local:latest
```
