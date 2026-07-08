from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.substitutions import LaunchConfiguration
from launch.launch_description_sources import AnyLaunchDescriptionSource
from launch_ros.actions import Node
from ament_index_python.packages import get_package_share_directory
import os


def generate_launch_description():
    device_id_arg = DeclareLaunchArgument(
        'device_id', default_value='-1', description='Camera device ID (-1 = auto-scan all)'
    )
    frame_width_arg = DeclareLaunchArgument(
        'frame_width', default_value='640', description='Camera frame width'
    )
    frame_height_arg = DeclareLaunchArgument(
        'frame_height', default_value='480', description='Camera frame height'
    )
    capture_fps_arg = DeclareLaunchArgument(
        'camera_capture_fps', default_value='30.0', description='Camera capture FPS'
    )
    reconnect_interval_arg = DeclareLaunchArgument(
        'camera_reconnect_interval_sec',
        default_value='1.0',
        description='Seconds between camera reconnect attempts',
    )
    read_failures_arg = DeclareLaunchArgument(
        'camera_read_failures_before_reconnect',
        default_value='3',
        description='Consecutive read failures before reconnect',
    )
    vision_input_topic_arg = DeclareLaunchArgument(
        'vision_input_topic',
        default_value='/camera/raw',
        description='Image topic consumed by the vision processor',
    )
    vision_model_path_arg = DeclareLaunchArgument(
        'vision_model_path',
        default_value='yolov8n.pt',
        description='Path to YOLO model used by the vision processor',
    )
    audio_device_arg = DeclareLaunchArgument(
        'audio_device',
        default_value='default',
        description='Audio capture device',
    )
    audio_sample_rate_arg = DeclareLaunchArgument(
        'audio_sample_rate',
        default_value='16000',
        description='Audio sample rate',
    )
    audio_channels_arg = DeclareLaunchArgument(
        'audio_channels', default_value='1', description='Audio channel count'
    )
    audio_chunk_size_arg = DeclareLaunchArgument(
        'audio_chunk_size',
        default_value='4096',
        description='Audio chunk size in bytes',
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
        capture_fps_arg,
        reconnect_interval_arg,
        read_failures_arg,
        vision_input_topic_arg,
        vision_model_path_arg,
        audio_device_arg,
        audio_sample_rate_arg,
        audio_channels_arg,
        audio_chunk_size_arg,
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
            executable='robot_sensor',
            name='robot_sensor_node',
            output='screen',
            parameters=[
                {'device_id': LaunchConfiguration('device_id')},
                {'frame_width': LaunchConfiguration('frame_width')},
                {'frame_height': LaunchConfiguration('frame_height')},
                {'capture_fps': LaunchConfiguration('camera_capture_fps')},
                {'reconnect_interval_sec': LaunchConfiguration('camera_reconnect_interval_sec')},
                {'read_failures_before_reconnect': LaunchConfiguration('camera_read_failures_before_reconnect')},
                {'audio_device': LaunchConfiguration('audio_device')},
                {'sample_rate': LaunchConfiguration('audio_sample_rate')},
                {'channels': LaunchConfiguration('audio_channels')},
                {'chunk_size': LaunchConfiguration('audio_chunk_size')},
            ],
        ),
        Node(
            package='r2k9_robot',
            executable='robot_vision_processor',
            name='robot_vision_processor_node',
            output='screen',
            parameters=[
                {'input_topic': LaunchConfiguration('vision_input_topic')},
                {'model_path': LaunchConfiguration('vision_model_path')},
            ],
        ),
    ])
