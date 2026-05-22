#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist

class DpadLoggerNode(Node):
    def __init__(self):
        super().__init__('dpad_logger_node')
        
        # Subscribe to the standard velocity commands topic
        # Rosbridge automatically translates Flutter WebSocket JSON strings into this topic format
        self.subscription = self.create_subscription(
            Twist,
            '/cmd_vel',
            self.listener_callback,
            10
        )
        self.get_logger().info('Mistibot R2K9 D-PAD Logger Node started. Awaiting signals from Flutter...')

    def listener_callback(self, msg):
        linear_x = msg.linear.x
        angular_z = msg.angular.z
        
        # Parse vector variations into descriptive directional logs
        direction = "STOP"
        if linear_x > 0:
            direction = "FORWARD ⬆️"
        elif linear_x < 0:
            direction = "BACKWARD ⬇️"
        elif angular_z > 0:
            direction = "STEER LEFT ⬅️"
        elif angular_z < 0:
            direction = "STEER RIGHT ➡️"

        self.get_logger().info(
            f"Received DPAD Input: [Direction: {direction}] -> Linear X: {linear_x:.2f}, Angular Z: {angular_z:.2f}"
        )

def main(args=None):
    rclpy.init(args=args)
    node = DpadLoggerNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info('Shutting down R2K9 node cleanly...')
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()

