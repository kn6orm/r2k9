#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
import json
import math
from std_msgs.msg import String
TIMEOUT=5

class ObjectImmobilityMonitor(Node):
    def __init__(self):
        super().__init__('object_immobility_monitor')

        # Subscribing to the lightweight telemetry coordinate stream
        self.bbox_sub = self.create_subscription(
            String,
            '/camera/bounding_boxes',
            self.bbox_callback,
            10
        )

        # Publish immobility alerts for UI consumption
        self.alert_pub = self.create_publisher(String, '/immobility_alert', 10)

        # Configuration thresholds
        self.STATIONARY_TOLERANCE_PIXELS = 250.0  # Drift tolerance window 
        self.IMMOBILE_DURATION_THRESHOLD = TIMEOUT   # Required duration in seconds

        # Tracking database layout:
        # { 'class_index': { 'last_centroid': (x, y), 'stationary_since': timestamp } }
        self.tracked_targets = {}

        self.get_logger().info("Object Immobility Monitoring Node has initialized.")

    def calculate_centroid(self, bbox):
        # bbox layout syntax: [x1, y1, x2, y2]
        x_center = (bbox[0] + bbox[2]) / 2.0
        y_center = (bbox[1] + bbox[3]) / 2.0
        return (x_center, y_center)

    def bbox_callback(self, msg):
        try:
            payload = json.loads(msg.data)
        except json.JSONDecodeError:
            self.get_logger().error("Failed to parse incoming bounding box JSON.")
            return

        current_time = self.get_clock().now().nanoseconds / 1e9
        detections = payload.get("detections", [])
        
        # Track what classes we see in the active frame
        active_classes_this_frame = set()

        for detection in detections:
            class_name = detection["class"]
            bbox = detection["bbox"]
            centroid = self.calculate_centroid(bbox)
            
            active_classes_this_frame.add(class_name)

            # If the class type isn't tracked yet, initialize monitoring state
            if class_name not in self.tracked_targets:
                self.tracked_targets[class_name] = {
                    "last_centroid": centroid,
                    "stationary_since": current_time,
                    "alert_triggered": False
                }
                continue

            target_data = self.tracked_targets[class_name]
            last_centroid = target_data["last_centroid"]

            # Calculate Euclidean distance between frames
            distance = math.sqrt(
                (centroid[0] - last_centroid[0])**2 + 
                (centroid[1] - last_centroid[1])**2
            )

            if distance <= self.STATIONARY_TOLERANCE_PIXELS:
                # Target is within the stationary drift tolerance envelope
                elapsed_duration = current_time - target_data["stationary_since"]
                self.get_logger().warn(f'duration is  {elapsed_duration}')
                if elapsed_duration >= self.IMMOBILE_DURATION_THRESHOLD and not target_data["alert_triggered"]:
                    alert_message = f"🚨 ALERT: {class_name.upper()} has stopped moving for {int(elapsed_duration)} seconds!"
                    self.get_logger().warn(alert_message)
                    alert_payload = String()
                    alert_payload.data = json.dumps({
                        "alert_type": "immobility",
                        "object_class": class_name,
                        "duration_seconds": int(elapsed_duration),
                        "message": alert_message,
                    })
                    self.alert_pub.publish(alert_payload)
                    target_data["alert_triggered"] = True
            else:
                # Target broke tolerance bound; reset its temporal tracker baseline
                self.tracked_targets[class_name] = {
                    "last_centroid": centroid,
                    "stationary_since": current_time,
                    "alert_triggered": False
                }

        # Housekeeping: Clean up targets from memory that left the frame entirely
        for localized_class in list(self.tracked_targets.keys()):
            if localized_class not in active_classes_this_frame:
                del self.tracked_targets[localized_class]

def main(args=None):
    rclpy.init(args=args)
    node = ObjectImmobilityMonitor()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()

