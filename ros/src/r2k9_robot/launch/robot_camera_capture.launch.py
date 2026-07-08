from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


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

    return LaunchDescription([
        device_id_arg,
        frame_width_arg,
        frame_height_arg,
        capture_fps_arg,
        reconnect_interval_arg,
        read_failures_arg,
        audio_device_arg,
        audio_sample_rate_arg,
        audio_channels_arg,
        audio_chunk_size_arg,
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
    ])