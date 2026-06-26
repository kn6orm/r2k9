# Use ROS Jazzyge
FROM ros:jazzy-ros-base-noble

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

RUN git clone -b docker https://github.com/kn6orm/r2k9.git

RUN cd r2k9/ros

RUN source ../tools/install.bash

# Copy the entrypoint script into the container
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

