# Set your domain to be different, if you have
# multiple robots on the same network/VPN
export ROS_DOMAIN_ID=100

source /opt/ros/jazzy/setup.bash

alias upd="sudo apt update -y ; sudo apt upgrade -y"
alias lsip="sudo nmap -sn 192.168.86.0/24"

export FLUTTER="$HOME/src/flutter"
export PATH="$PATH:$FLUTTER/bin"


alias lsdev="nmap -sn 192.168.86.0/24"
alias lslocal="sudo arp-scan --interface=enp24s0 192.168.73.0/24"

export CCACHE_DIR=$HOME/ccache
alias r2b='colcon build --symlink-install --cmake-args -DCMAKE_CXX_FLAGS="-Wno-error=overloaded-virtual"'
alias r2i="source install/setup.bash"
alias r2l="screen -LdmS r2k9_robot ros2 launch r2k9_robot r2k9.launch.py"
alias r2k="screen -LdmS kobuki ros2 launch kobuki kobuki.launch.py"
alias r2v="ros2 run rqt_image_view rqt_image_view"
alias r2r="git submodule update --init --recursive"

export VISUAL=vi

