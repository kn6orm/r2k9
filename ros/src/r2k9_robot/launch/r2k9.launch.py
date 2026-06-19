from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    device_id_arg = DeclareLaunchArgument(
        'device_id', default_value='0', description='Camera device ID'
    )
    frame_width_arg = DeclareLaunchArgument(
        'frame_width', default_value='640', description='Camera frame width'
    )
    frame_height_arg = DeclareLaunchArgument(
        'frame_height', default_value='480', description='Camera frame height'
    )

    return LaunchDescription([
        device_id_arg,
        frame_width_arg,
        frame_height_arg,
        Node(
            package='r2k9_robot',
            executable='dpad_logger',
            name='dpad_logger_node',
            output='screen',
        ),
        Node(
            package='r2k9_robot',
            executable='immobility_monitor',
            name='object_immobility_monitor',
            output='screen',
        ),
        Node(
            package='r2k9_robot',
            executable='robot_vision',
            name='robot_vision_node',
            output='screen',
            parameters=[
                {'device_id': LaunchConfiguration('device_id')},
                {'frame_width': LaunchConfiguration('frame_width')},
                {'frame_height': LaunchConfiguration('frame_height')},
            ],
        ),
    ])
