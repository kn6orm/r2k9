from setuptools import find_packages, setup

package_name = 'r2k9_robot'

setup(
    name=package_name,
    version='0.0.1',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name] if False else []), # Placeholder if directory empty
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Developer',
    maintainer_email='your_email@example.com',
    description='ROS 2 control and logging node for Mistibot r2k9',
    license='Apache-2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'dpad_logger = r2k9_robot.dpad_logger_node:main'
        ],
    },
)

