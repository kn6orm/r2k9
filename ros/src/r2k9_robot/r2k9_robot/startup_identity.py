#!/usr/bin/env python3
import os
import socket


def log_startup_identity(node):
    """Log ROS domain, node name, and host immediately after node startup."""
    ros_domain_id = os.getenv('ROS_DOMAIN_ID', '<unset>')
    host = socket.gethostname()
    node.get_logger().info(
        f"[STARTUP] ROS_DOMAIN_ID={ros_domain_id} node={node.get_name()} host={host}"
    )
