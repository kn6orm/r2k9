from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    return LaunchDescription([
        Node(
            package='r2k9_robot',
            executable='immobility_monitor',
            name='object_immobility_monitor',
            output='screen',
        ),
    ])
