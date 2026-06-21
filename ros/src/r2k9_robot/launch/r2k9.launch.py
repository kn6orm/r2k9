from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.substitutions import LaunchConfiguration
from launch.launch_description_sources import AnyLaunchDescriptionSource
from launch_ros.actions import Node
from ament_index_python.packages import get_package_share_directory
import os


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

    rosbridge_dir = get_package_share_directory('rosbridge_server')
    rosbridge_launch = IncludeLaunchDescription(
        AnyLaunchDescriptionSource(
            os.path.join(rosbridge_dir, 'launch', 'rosbridge_websocket_launch.xml')
        )
    )

    return LaunchDescription([
        device_id_arg,
        frame_width_arg,
        frame_height_arg,
        rosbridge_launch,
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
            arguments=[
                '--ros-args',
                '--params-file',
                'src/r2k9_robot/config/immobility_monitor.yaml',
            ],
        ),
        Node(
            package='r2k9_robot',
            executable='kobuki_controller',
            name='kobuki_controller_node',
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
