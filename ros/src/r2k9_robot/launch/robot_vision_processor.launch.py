from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
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

    return LaunchDescription([
        vision_input_topic_arg,
        vision_model_path_arg,
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