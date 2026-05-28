#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist

class KobukiControllerNode(Node):
    def __init__(self):
        super().__init__('kobuki_controller_node')
        
        # 1. Listen for the Twist velocity payloads arriving from the Flutter App
        self.cmd_vel_subscription = self.create_subscription(
            Twist,
            '/cmd_vel',
            self.cmd_vel_callback,
            10
        )
        
        # 2. Relays mapped velocity vectors down to Kobuki's dedicated input multiplexer
        self.kobuki_publisher = self.create_publisher(
            Twist,
            '/commands/velocity', # Target input topic for the kobuki_node driver
            10
        )
        
        self.get_logger().info('Kobuki Core Interface Node Initialized.')

    def cmd_vel_callback(self, msg: Twist):
        # Extract inputs mapped from your Flutter movement packets
        linear_x = msg.linear.x
        angular_z = msg.angular.z
        
        self.get_logger().info(f'Routing Teleop Payload -> Linear X: {linear_x:.2f}, Angular Z: {angular_z:.2f}')
        
        # Instantiate a clean Twist container to map directly downstream
        command_msg = Twist()
        command_msg.linear.x = linear_x
        command_msg.angular.z = angular_z
        
        # Publish to the hardware base driver layer
        self.kobuki_publisher.publish(command_msg)

def main(args=None):
    rclpy.init(args=args)
    node = KobukiControllerNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info('Shutting down Kobuki Controller Node gracefully.')
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
