# Use official ROS 2 Jazzy Base image on Ubuntu Noble
FROM ros:jazzy-ros-base-noble

# Prevent interactive prompts during apt installation cycles
ENV DEBIAN_FRONTEND=noninteractive

# Force the image builder shell to use Bash explicitly
SHELL ["/bin/bash", "-c"]

# Clone the R2K9 codebase targeting your dedicated docker branch
RUN git clone -b docker https://github.com/kn6orm/r2k9.git /workspace/r2k9

# Use WORKDIR to permanently shift context to the install directory
WORKDIR /workspace/r2k9/ros

# Set build environment triggers and invoke the installation script using bash rules
ENV DOCKER_BUILD=1
RUN source ../tools/install.bash

# Copy and configure your system entrypoint environment
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]