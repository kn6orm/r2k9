from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
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
    audio_alert_phrase_arg = DeclareLaunchArgument(
        'audio_alert_phrase',
        default_value='r2k9 help me',
        description='Speech trigger phrase for audio alert monitor',
    )
    audio_alert_model_path_arg = DeclareLaunchArgument(
        'audio_alert_model_path',
        default_value='',
        description='Optional path to Vosk speech model',
    )
    audio_alert_cooldown_arg = DeclareLaunchArgument(
        'audio_alert_cooldown_seconds',
        default_value='10.0',
        description='Minimum seconds between repeated audio alerts',
    )

    return LaunchDescription([
        audio_device_arg,
        audio_sample_rate_arg,
        audio_channels_arg,
        audio_chunk_size_arg,
        audio_alert_phrase_arg,
        audio_alert_model_path_arg,
        audio_alert_cooldown_arg,
        Node(
            package='r2k9_robot',
            executable='robot_audio',
            name='robot_audio_node',
            output='screen',
            parameters=[
                {'audio_device': LaunchConfiguration('audio_device')},
                {'sample_rate': LaunchConfiguration('audio_sample_rate')},
                {'channels': LaunchConfiguration('audio_channels')},
                {'chunk_size': LaunchConfiguration('audio_chunk_size')},
            ],
        ),
        Node(
            package='r2k9_robot',
            executable='audio_alert_monitor',
            name='audio_alert_monitor',
            output='screen',
            parameters=[
                {'audio_topic': '/audio/web'},
                {'alert_topic': '/audio_alert'},
                {'trigger_phrase': LaunchConfiguration('audio_alert_phrase')},
                {'model_path': LaunchConfiguration('audio_alert_model_path')},
                {
                    'cooldown_seconds': LaunchConfiguration(
                        'audio_alert_cooldown_seconds'
                    )
                },
            ],
        ),
    ])
