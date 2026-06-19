from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    return LaunchDescription([
        Node(
            package='r2k9_robot',
            executable='web_video_server',
            name='web_video_server_node',
            output='screen',
        ),
    ])
