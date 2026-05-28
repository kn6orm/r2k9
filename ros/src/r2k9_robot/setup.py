from setuptools import find_packages, setup

package_name = 'r2k9_robot'

setup(
    name=package_name,
    version='0.0.0',
    packages=[package_name], 

    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='sca',
    maintainer_email='sca@photon.local',
    description='Mistibot core vision and telemetry tracking package',
    license='GPL-3.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'dpad_logger = r2k9_robot.dpad_logger_node:main',
            'robot_vision = r2k9_robot.robot_vision_node:main',
            'immobility_monitor = r2k9_robot.object_immobility_monitor:main',
            'kobuki_controller = r2k9_robot.kobuki_controller_node:main',
        ],
    },
)

