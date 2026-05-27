#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
import cv2
import json
from cv_bridge import CvBridge
from sensor_msgs.msg import Image
from std_msgs.msg import String
from ultralytics import YOLO

class RobotVisionNode(Node):
    def __init__(self):
        super().__init__('robot_vision_node')
        
        # 1. IMMEDIATE DEFINITIONS: Create your topic communication channels FIRST
        self.image_pub = self.create_publisher(Image, '/camera/processed_image', 10)
        self.bbox_pub = self.create_publisher(String, '/camera/bounding_boxes', 10)

        # Declare parameters
        self.declare_parameter('device_id', 0)
        self.declare_parameter('frame_width', 640)
        self.declare_parameter('frame_height', 480)

        device_id = self.get_parameter('device_id').value
        width = self.get_parameter('frame_width').value
        height = self.get_parameter('frame_height').value

        # 2. HARDWARE LAYER: Initialize Video Capture (USB Webcam)
        self.cap = cv2.VideoCapture(device_id)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        
        if not self.cap.isOpened():
            self.get_logger().error(f"Could not open USB camera device ID: {device_id}")
            raise RuntimeError("Camera initialization failed.")

        # 3. AI LAYER: Initialize CV Bridge and YOLO Model
        self.bridge = CvBridge()
        self.model = YOLO('yolov8n.pt') 
        
        # Target classes: 0 = person, 15 = cat, 16 = dog
        self.target_classes = [0, 15, 16]
        
        # 4. TIMER EXECUTION: Start the loop callback last at ~30 FPS
        self.timer = self.create_timer(0.033, self.process_frame_callback)
        self.get_logger().info("Robot Vision Node with unified publishers successfully started.")

    def process_frame_callback(self):
        ret, frame = self.cap.read()
        if not ret:
            return

        # Run YOLO inference
        results = self.model(frame, classes=self.target_classes, verbose=False)

        # Structure to hold tracking telemetry data
        detected_objects = []

        for result in results:
            for box in result.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                confidence = float(box.conf[0])
                class_id = int(box.cls[0])
                class_name = self.model.names[class_id]

                detected_objects.append({
                    "class": class_name,
                    "confidence": round(confidence, 2),
                    "bbox": [x1, y1, x2, y2]
                })

                # DRAWING FIX: Draw visual bounding box overlays using complete arguments
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                
                label = f"{class_name.capitalize()} {confidence:.2f}"
                cv2.putText(frame, label, (x1, max(y1 - 10, 10)), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

        # 1. Transmit raw Bounding Box coordinates
        bbox_msg = String()
        bbox_msg.data = json.dumps({
            "timestamp": int(self.get_clock().now().nanoseconds / 1e9),
            "detections": detected_objects
        })
        self.bbox_pub.publish(bbox_msg)

        # 2. Transmit the visual image frame
        ros_image_msg = self.bridge.cv2_to_imgmsg(frame, encoding="bgr8")
        self.image_pub.publish(ros_image_msg)

    def destroy_node(self):
        if self.cap.isOpened():
            self.cap.release()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    node = RobotVisionNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        # Check context health to avoid double-shutdown exceptions
        if rclpy.ok():
            node.destroy_node()
            rclpy.shutdown()

if __name__ == '__main__':
    main()

