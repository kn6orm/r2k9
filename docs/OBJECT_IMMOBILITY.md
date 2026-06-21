# R2K9 ROS Parameters

This document describes runtime parameters for the immobility monitor node.

## Node

- Node name: object_immobility_monitor
- Package: r2k9_robot
- Executable: immobility_monitor

## Parameters

| Parameter | Type | Default | Description |
|---|---|---:|---|
| stationary_tolerance_pixels | float | 250.0 | Maximum centroid drift (in pixels) still considered stationary between frames. |
| immobile_duration_threshold | float | 5.0 | Time in seconds an object must remain within tolerance before an alert is published. |

Parameter defaults are declared in [ros/src/r2k9_robot/r2k9_robot/object_immobility_monitor.py](ros/src/r2k9_robot/r2k9_robot/object_immobility_monitor.py).

## List Current Parameters

Start the node first:

```bash
ros2 run r2k9_robot immobility_monitor
```

In another terminal, list all nodes and parameters:

```bash
ros2 node list
ros2 param list /object_immobility_monitor
```

## Read Current Parameter Values

```bash
ros2 param get /object_immobility_monitor stationary_tolerance_pixels
ros2 param get /object_immobility_monitor immobile_duration_threshold
```

## Change Parameters At Runtime

These changes apply to the running node instance:

```bash
ros2 param set /object_immobility_monitor stationary_tolerance_pixels 120.0
ros2 param set /object_immobility_monitor immobile_duration_threshold 3.0
```

Verify after setting:

```bash
ros2 param get /object_immobility_monitor stationary_tolerance_pixels
ros2 param get /object_immobility_monitor immobile_duration_threshold
```

## Start With a YAML Parameter File

A ready-to-use parameter file exists at [ros/src/r2k9_robot/config/immobility_monitor.yaml](ros/src/r2k9_robot/config/immobility_monitor.yaml).

Run with file:

```bash
ros2 run r2k9_robot immobility_monitor --ros-args --params-file /Users/sca/src/r2k9/ros/src/r2k9_robot/config/immobility_monitor.yaml
```

## Persisting Changes

Runtime ros2 param set changes are not persisted across restarts.

To keep values permanently:

1. Edit [ros/src/r2k9_robot/config/immobility_monitor.yaml](ros/src/r2k9_robot/config/immobility_monitor.yaml).
2. Start the node with --params-file.
