#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
import cv2
import json
import time
import glob
import os
from cv_bridge import CvBridge
from sensor_msgs.msg import Image, CompressedImage
from std_msgs.msg import String
from ultralytics import YOLO
from r2k9_robot.startup_identity import log_startup_identity

class RobotVisionNode(Node):
    def __init__(self):
        super().__init__('robot_vision_node')
        log_startup_identity(self)
        
        # 1. IMMEDIATE DEFINITIONS: Create your topic communication channels FIRST
        self.image_pub = self.create_publisher(Image, '/camera/processed_image', 10)
        self.bbox_pub = self.create_publisher(String, '/camera/bounding_boxes', 10)
        self.compressed_pub = self.create_publisher(CompressedImage, '/camera/web', 10)

        # Declare parameters
        self.declare_parameter('device_id', -1)
        self.declare_parameter('frame_width', 640)
        self.declare_parameter('frame_height', 480)
        self.declare_parameter('reconnect_interval_sec', 1.0)
        self.declare_parameter('read_failures_before_reconnect', 3)

        self.device_id = self.get_parameter('device_id').value
        self.width = int(self.get_parameter('frame_width').value)
        self.height = int(self.get_parameter('frame_height').value)
        self.reconnect_interval_sec = float(self.get_parameter('reconnect_interval_sec').value)
        self.read_failures_before_reconnect = int(
            self.get_parameter('read_failures_before_reconnect').value
        )

        # 2. HARDWARE LAYER: Initialize Video Capture with reconnect state.
        self.cap = None
        self.current_camera_source = None
        self.last_reconnect_attempt = 0.0
        self.consecutive_read_failures = 0
        self.next_camera_candidate_index = 0
        self._connect_camera()

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
        self.get_logger().info(
            "[VISION_INIT] Robot Vision Node started. "
            f"Preferred device={self.device_id}, Resolution={self.width}x{self.height}"
        )

    def _release_camera(self):
        if self.cap is not None and self.cap.isOpened():
            self.cap.release()
        self.cap = None
        self.current_camera_source = None

    def _camera_candidates(self):
        candidates = []

        preferred = self.device_id
        if isinstance(preferred, str):
            preferred = preferred.strip()
            if preferred:
                if preferred.isdigit():
                    preferred_index = int(preferred)
                    if preferred_index >= 0:
                        candidates.append(preferred_index)
                else:
                    candidates.append(preferred)
        else:
            preferred_index = int(preferred)
            if preferred_index >= 0:
                candidates.append(preferred_index)

        by_id_links = sorted(glob.glob('/dev/v4l/by-id/*'))
        for link in by_id_links:
            try:
                resolved = os.path.realpath(link)
            except OSError:
                continue
            if resolved.startswith('/dev/video'):
                candidates.append(resolved)

        video_nodes = sorted(
            glob.glob('/dev/video*'),
            key=lambda p: int(p.replace('/dev/video', '')) if p.replace('/dev/video', '').isdigit() else 10**9,
        )
        candidates.extend(video_nodes)

        unique = []
        seen = set()
        for item in candidates:
            key = str(item)
            if key in seen:
                continue
            seen.add(key)
            unique.append(item)
        return unique

    def _ordered_camera_candidates(self):
        candidates = self._camera_candidates()
        if not candidates:
            return []

        if self.next_camera_candidate_index >= len(candidates):
            self.next_camera_candidate_index = 0

        start = self.next_camera_candidate_index
        ordered = candidates[start:] + candidates[:start]
        self.next_camera_candidate_index = (start + 1) % len(candidates)
        return ordered

    def _open_camera_candidate(self, source):
        cap = cv2.VideoCapture(source)
        if not cap.isOpened():
            cap.release()
            return None

        cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)

        # Ensure the backend can actually produce frames before accepting source.
        for _ in range(3):
            ret, _ = cap.read()
            if ret:
                return cap
            time.sleep(0.02)

        cap.release()
        return None

    def _connect_camera(self):
        now = time.time()
        if now - self.last_reconnect_attempt < self.reconnect_interval_sec:
            return False
        self.last_reconnect_attempt = now

        self._release_camera()
        for source in self._ordered_camera_candidates():
            cap = self._open_camera_candidate(source)
            if cap is None:
                continue
            self.cap = cap
            self.current_camera_source = source
            self.consecutive_read_failures = 0
            self.get_logger().info(f"[CAMERA] Connected to camera source: {source}")
            return True

        self.get_logger().warn("[CAMERA] No available camera source found; will retry")
        return False

    def process_frame_callback(self):
        frame_start = time.time()
        self.frame_counter += 1

        if self.cap is None or not self.cap.isOpened():
            self._connect_camera()
            return
        
        # [STAGE 1] Capture frame from USB camera
        ret, frame = self.cap.read()
        if not ret:
            self.consecutive_read_failures += 1
            if self.consecutive_read_failures >= self.read_failures_before_reconnect:
                self.get_logger().warn(
                    f"[CAMERA] Frame read failed {self.consecutive_read_failures}x from "
                    f"{self.current_camera_source}; reconnecting"
                )
                self._connect_camera()
            else:
                self.get_logger().warn(
                    f"[FRAME_{self.frame_counter}] Failed to read frame from camera "
                    f"({self.consecutive_read_failures}/{self.read_failures_before_reconnect})"
                )
            return
        self.consecutive_read_failures = 0
        
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
        self._release_camera()
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

