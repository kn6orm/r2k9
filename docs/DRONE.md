
ros2 launch r2k9_robot r2k9.launch.py

This starts both the drone and control stacks by default.

To launch only the drone-side nodes:

ros2 launch r2k9_robot r2k9.launch.py drone:=true

To launch only the control-side nodes:

ros2 launch r2k9_robot r2k9.launch.py control:=true

You can also explicitly disable one side:

ros2 launch r2k9_robot r2k9.launch.py drone:=false

ros2 launch r2k9_robot r2k9.launch.py control:=false
