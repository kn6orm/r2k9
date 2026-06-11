from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    return LaunchDescription([
        Node(
            package='r2k9_robot',
            executable='dpad_logger',
            name='dpad_logger_node',
            output='screen',
        ),
    ])
