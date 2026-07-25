#!/usr/bin/env python3
import glob
import os
import time

import cv2
import rclpy
from cv_bridge import CvBridge
from rclpy.node import Node
from sensor_msgs.msg import Image
from r2k9_robot.startup_identity import log_startup_identity


class RobotCameraCaptureNode(Node):
    def __init__(self):
        super().__init__('robot_camera_capture_node')
        log_startup_identity(self)

        self.raw_image_pub = self.create_publisher(Image, '/camera/raw', 10)

        self.declare_parameter('device_id', -1)
        self.declare_parameter('frame_width', 640)
        self.declare_parameter('frame_height', 480)
        self.declare_parameter('capture_fps', 30.0)
        self.declare_parameter('reconnect_interval_sec', 1.0)
        self.declare_parameter('read_failures_before_reconnect', 3)

        self.device_id = self.get_parameter('device_id').value
        self.width = int(self.get_parameter('frame_width').value)
        self.height = int(self.get_parameter('frame_height').value)
        self.capture_fps = float(self.get_parameter('capture_fps').value)
        self.reconnect_interval_sec = float(self.get_parameter('reconnect_interval_sec').value)
        self.read_failures_before_reconnect = int(
            self.get_parameter('read_failures_before_reconnect').value
        )

        self.bridge = CvBridge()

        self.cap = None
        self.current_camera_source = None
        self.last_reconnect_attempt = 0.0
        self.consecutive_read_failures = 0
        self.next_camera_candidate_index = 0
        self.frame_counter = 0

        self._connect_camera()

        timer_period = 1.0 / self.capture_fps if self.capture_fps > 0 else 0.033
        self.timer = self.create_timer(timer_period, self.capture_frame_callback)
        self.get_logger().info(
            "[CAMERA_CAPTURE_INIT] Started camera capture node. "
            f"Preferred device={self.device_id}, Resolution={self.width}x{self.height}, FPS={self.capture_fps}"
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
            self.get_logger().info(f"[CAMERA_CAPTURE] Connected to camera source: {source}")
            return True

        self.get_logger().warn("[CAMERA_CAPTURE] No available camera source found; will retry")
        return False

    def capture_frame_callback(self):
        self.frame_counter += 1

        if self.cap is None or not self.cap.isOpened():
            self._connect_camera()
            return

        ret, frame = self.cap.read()
        if not ret:
            self.consecutive_read_failures += 1
            if self.consecutive_read_failures >= self.read_failures_before_reconnect:
                self.get_logger().warn(
                    f"[CAMERA_CAPTURE] Frame read failed {self.consecutive_read_failures}x from "
                    f"{self.current_camera_source}; reconnecting"
                )
                self._connect_camera()
            return

        self.consecutive_read_failures = 0

        raw_msg = self.bridge.cv2_to_imgmsg(frame, encoding='bgr8')
        raw_msg.header.frame_id = f"raw_frame_{self.frame_counter}"
        raw_msg.header.stamp = self.get_clock().now().to_msg()
        self.raw_image_pub.publish(raw_msg)

    def destroy_node(self):
        self._release_camera()
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = RobotCameraCaptureNode()
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