# Use official Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up the locale required by ROS 2
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Install initial dependencies and software-properties-common
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add the ROS 2 apt repository GPG key
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Add the repository to your sources list
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 Jazzy packages
# Options: ros-jazzy-desktop (with GUI tools) or ros-jazzy-ros-base (barebones/headless)
RUN apt-get update && apt-get install -y \
    ros-jazzy-ros-base \
    ros-dev-tools \
    && rm -rf /var/lib/apt/lists/*

# Automatically source ROS 2 environment for interactive bash sessions
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc

# Copy the entrypoint script into the container
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

