#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from cv_bridge import CvBridge
from sensor_msgs.msg import Image
from std_msgs.msg import String
import cv2
import zenoh

class ZenohBridgeNode(Node):
    def __init__(self):
        super().__init__('zenoh_bridge_node')
        self.get_logger().info('Starting Zenoh Bridge Node')

        self.bridge = CvBridge()

        # Subscribe to the processed image and bounding boxes
        self.create_subscription(Image, '/camera/processed_image', self.image_callback, 10)
        self.create_subscription(String, '/camera/bounding_boxes', self.bbox_callback, 10)

        # Initialize zenoh session if available
        self.zenoh_session = None
        if zenoh is not None:
            try:
                self.zenoh_session = zenoh.open()
                self.get_logger().info('Zenoh session opened successfully')
            except Exception as e:
                self.get_logger().error(f'Failed to open Zenoh session: {e}')
                self.zenoh_session = None
        else:
            self.get_logger().warning('Zenoh Python library not available; bridge will not publish to Zenoh')

    def image_callback(self, msg: Image):
        # Convert ROS Image to OpenCV image
        try:
            cv_image = self.bridge.imgmsg_to_cv2(msg, desired_encoding='bgr8')
        except Exception as e:
            self.get_logger().error(f'Failed to convert ROS Image: {e}')
            return

        # Encode as JPEG
        ret, jpeg = cv2.imencode('.jpg', cv_image, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        if not ret:
            self.get_logger().error('Failed to encode image to JPEG')
            return

        jpeg_bytes = jpeg.tobytes()

        # Publish to zenoh if session exists
        if self.zenoh_session is not None:
            try:
                # Use a simple key for Zenoh; consumers can subscribe to this key
                self.zenoh_session.put('r2k9/camera/processed_image', jpeg_bytes)
            except Exception as e:
                self.get_logger().error(f'Failed to publish image to Zenoh: {e}')

    def bbox_callback(self, msg: String):
        if self.zenoh_session is not None:
            try:
                self.zenoh_session.put('r2k9/camera/bounding_boxes', msg.data.encode('utf-8'))
            except Exception as e:
                self.get_logger().error(f'Failed to publish bounding boxes to Zenoh: {e}')

    def destroy_node(self):
        # Close zenoh session
        if self.zenoh_session is not None:
            try:
                self.zenoh_session.close()
            except Exception:
                pass
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = ZenohBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if rclpy.ok():
            node.destroy_node()
            rclpy.shutdown()

if __name__ == '__main__':
    main()
