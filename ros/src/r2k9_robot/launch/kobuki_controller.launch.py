from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    return LaunchDescription([
        Node(
            package='r2k9_robot',
            executable='kobuki_controller',
            name='kobuki_controller_node',
            output='screen',
        ),
    ])
