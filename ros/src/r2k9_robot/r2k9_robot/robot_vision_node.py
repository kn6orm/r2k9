#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
import cv2
import json
import time
from cv_bridge import CvBridge
from sensor_msgs.msg import Image, CompressedImage
from std_msgs.msg import String
from ultralytics import YOLO

class RobotVisionNode(Node):
    def __init__(self):
        super().__init__('robot_vision_node')
        
        # 1. IMMEDIATE DEFINITIONS: Create your topic communication channels FIRST
        self.image_pub = self.create_publisher(Image, '/camera/processed_image', 10)
        self.bbox_pub = self.create_publisher(String, '/camera/bounding_boxes', 10)
        self.compressed_pub = self.create_publisher(CompressedImage, '/camera/web', 10)

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
        
        # 4. INSTRUMENTATION: Frame tracking and metrics
        self.frame_counter = 0
        self.last_log_time = time.time()
        self.frames_since_log = 0

        # 5. TIMER EXECUTION: Start the loop callback last at ~30 FPS
        self.timer = self.create_timer(0.033, self.process_frame_callback)
        self.get_logger().info(f"[VISION_INIT] Robot Vision Node with unified publishers successfully started. Device={device_id}, Resolution={width}x{height}")

    def process_frame_callback(self):
        frame_start = time.time()
        self.frame_counter += 1
        
        # [STAGE 1] Capture frame from USB camera
        ret, frame = self.cap.read()
        if not ret:
            self.get_logger().warn(f"[FRAME_{self.frame_counter}] Failed to read frame from camera")
            return
        
        capture_time = time.time() - frame_start
        self.get_logger().debug(f"[FRAME_{self.frame_counter}] Captured from camera - shape={frame.shape}, capture_time={capture_time*1000:.2f}ms")

        # [STAGE 2] Run YOLO inference
        inference_start = time.time()
        results = self.model(frame, classes=self.target_classes, verbose=False)
        inference_time = time.time() - inference_start
        self.get_logger().debug(f"[FRAME_{self.frame_counter}] YOLO inference complete - time={inference_time*1000:.2f}ms")

        # Structure to hold tracking telemetry data
        detected_objects = []

        # [STAGE 3] Process detections and draw boxes
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

        if detected_objects:
            self.get_logger().info(f"[FRAME_{self.frame_counter}] Detected {len(detected_objects)} objects: {[obj['class'] for obj in detected_objects]}")

        # [STAGE 4] Publish bounding box data
        bbox_msg = String()
        bbox_msg.data = json.dumps({
            "timestamp": int(self.get_clock().now().nanoseconds / 1e9),
            "frame_id": self.frame_counter,
            "detections": detected_objects
        })
        self.bbox_pub.publish(bbox_msg)
        self.get_logger().debug(f"[FRAME_{self.frame_counter}] Published bounding boxes to /camera/bounding_boxes")

        # [STAGE 5] Convert and publish image
        publish_start = time.time()
        ros_image_msg = self.bridge.cv2_to_imgmsg(frame, encoding="bgr8")
        ros_image_msg.header.frame_id = f"frame_{self.frame_counter}"
        ros_image_msg.header.stamp = self.get_clock().now().to_msg()
        self.image_pub.publish(ros_image_msg)
        publish_time = time.time() - publish_start
        self.get_logger().debug(f"[FRAME_{self.frame_counter}] Published image to /camera/processed_image - publish_time={publish_time*1000:.2f}ms")

        # [STAGE 6] Also publish compressed JPEG to /camera/web for UI
        try:
            comp_start = time.time()
            ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            if ret:
                compressed_msg = CompressedImage()
                compressed_msg.header = ros_image_msg.header
                compressed_msg.format = 'jpeg'
                compressed_msg.data = bytes(buffer)
                self.compressed_pub.publish(compressed_msg)
                comp_time = time.time() - comp_start
                self.get_logger().debug(f"[FRAME_{self.frame_counter}] Published compressed image to /camera/web - time={comp_time*1000:.2f}ms")
            else:
                self.get_logger().error(f"[FRAME_{self.frame_counter}] JPEG encoding failed")
        except Exception as e:
            self.get_logger().error(f"[FRAME_{self.frame_counter}] Exception publishing /camera/web: {e}")

        # Periodic FPS logging
        self.frames_since_log += 1
        now = time.time()
        if now - self.last_log_time >= 5.0:
            fps = self.frames_since_log / (now - self.last_log_time)
            total_time = time.time() - frame_start
            self.get_logger().info(f"[FPS_STATS] Frame {self.frame_counter}: {fps:.1f} FPS, total_time={total_time*1000:.2f}ms")
            self.frames_since_log = 0
            self.last_log_time = now

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

