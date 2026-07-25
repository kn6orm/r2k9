#!/usr/bin/env python3
import json
import time

import cv2
import rclpy
from cv_bridge import CvBridge
from rclpy.node import Node
from sensor_msgs.msg import CompressedImage, Image
from std_msgs.msg import String
from ultralytics import YOLO
from r2k9_robot.startup_identity import log_startup_identity


class RobotVisionProcessorNode(Node):
    def __init__(self):
        super().__init__('robot_vision_processor_node')
        log_startup_identity(self)

        self.image_pub = self.create_publisher(Image, '/camera/processed_image', 10)
        self.bbox_pub = self.create_publisher(String, '/camera/bounding_boxes', 10)
        self.compressed_pub = self.create_publisher(CompressedImage, '/camera/web', 10)

        self.declare_parameter('input_topic', '/camera/raw')
        self.declare_parameter('model_path', 'yolov8n.pt')
        self.declare_parameter('target_classes', [0, 15, 16])
        self.declare_parameter('jpeg_quality', 80)

        self.input_topic = str(self.get_parameter('input_topic').value)
        model_path = str(self.get_parameter('model_path').value)
        self.target_classes = [int(x) for x in self.get_parameter('target_classes').value]
        self.jpeg_quality = int(self.get_parameter('jpeg_quality').value)

        self.bridge = CvBridge()
        self.model = YOLO(model_path)

        self.frame_counter = 0
        self.last_log_time = time.time()
        self.frames_since_log = 0

        self.raw_image_sub = self.create_subscription(
            Image,
            self.input_topic,
            self.process_raw_image_callback,
            10,
        )

        self.get_logger().info(
            "[VISION_PROCESSOR_INIT] Started vision processor node. "
            f"Input={self.input_topic}, Model={model_path}, TargetClasses={self.target_classes}"
        )

    def process_raw_image_callback(self, msg):
        frame_start = time.time()
        self.frame_counter += 1

        try:
            frame = self.bridge.imgmsg_to_cv2(msg, desired_encoding='bgr8')
        except Exception as exc:
            self.get_logger().error(f"[FRAME_{self.frame_counter}] Failed to decode input image: {exc}")
            return

        inference_start = time.time()
        results = self.model(frame, classes=self.target_classes, verbose=False)
        inference_time = time.time() - inference_start
        self.get_logger().debug(
            f"[FRAME_{self.frame_counter}] YOLO inference complete - time={inference_time*1000:.2f}ms"
        )

        detected_objects = []

        for result in results:
            for box in result.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                confidence = float(box.conf[0])
                class_id = int(box.cls[0])
                class_name = self.model.names[class_id]

                detected_objects.append(
                    {
                        'class': class_name,
                        'confidence': round(confidence, 2),
                        'bbox': [x1, y1, x2, y2],
                    }
                )

                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                label = f"{class_name.capitalize()} {confidence:.2f}"
                cv2.putText(
                    frame,
                    label,
                    (x1, max(y1 - 10, 10)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.5,
                    (0, 255, 0),
                    2,
                )

        bbox_msg = String()
        bbox_msg.data = json.dumps(
            {
                'timestamp': int(self.get_clock().now().nanoseconds / 1e9),
                'frame_id': self.frame_counter,
                'detections': detected_objects,
            }
        )
        self.bbox_pub.publish(bbox_msg)

        processed_msg = self.bridge.cv2_to_imgmsg(frame, encoding='bgr8')
        processed_msg.header = msg.header
        self.image_pub.publish(processed_msg)

        try:
            ok, buffer = cv2.imencode(
                '.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality]
            )
            if ok:
                compressed_msg = CompressedImage()
                compressed_msg.header = msg.header
                compressed_msg.format = 'jpeg'
                compressed_msg.data = bytes(buffer)
                self.compressed_pub.publish(compressed_msg)
            else:
                self.get_logger().error(
                    f"[FRAME_{self.frame_counter}] JPEG encoding failed"
                )
        except Exception as exc:
            self.get_logger().error(
                f"[FRAME_{self.frame_counter}] Exception publishing /camera/web: {exc}"
            )

        self.frames_since_log += 1
        now = time.time()
        if now - self.last_log_time >= 5.0:
            fps = self.frames_since_log / (now - self.last_log_time)
            total_time = time.time() - frame_start
            self.get_logger().info(
                f"[VISION_PROCESSOR_FPS] Frame {self.frame_counter}: {fps:.1f} FPS, total_time={total_time*1000:.2f}ms"
            )
            self.frames_since_log = 0
            self.last_log_time = now


def main(args=None):
    rclpy.init(args=args)
    node = RobotVisionProcessorNode()
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