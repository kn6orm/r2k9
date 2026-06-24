#!/usr/bin/env python3
import base64
import json
import os
import re
from typing import Optional

import rclpy
from rclpy.node import Node
from std_msgs.msg import String


from vosk import KaldiRecognizer, Model, SetLogLevel

class AudioAlertMonitor(Node):
    def __init__(self):
        super().__init__('audio_alert_monitor')

        self.declare_parameter('audio_topic', '/audio/web')
        self.declare_parameter('alert_topic', '/audio_alert')
        self.declare_parameter('trigger_phrase', 'r2k9 help me')
        self.declare_parameter('cooldown_seconds', 10.0)
        self.declare_parameter('model_path', '')

        self.audio_topic = str(self.get_parameter('audio_topic').value)
        self.alert_topic = str(self.get_parameter('alert_topic').value)
        self.trigger_phrase = self._normalize_text(
            str(self.get_parameter('trigger_phrase').value)
        )
        self.cooldown_seconds = max(0.0, float(self.get_parameter('cooldown_seconds').value))
        model_path = str(self.get_parameter('model_path').value)

        self.alert_pub = self.create_publisher(String, self.alert_topic, 10)
        self.last_alert_time_sec = 0.0
        self.model = None
        self.recognizer = None
        self.recognizer_sample_rate = None

        if SetLogLevel is not None:
            SetLogLevel(-1)

        self.model = self._load_model(model_path)
        if self.model is None:
            self.get_logger().error(
                '[AUDIO_ALERT] Vosk model unavailable; node is idle. '
                'Install vosk and provide model_path or VOSK_MODEL_PATH.'
            )

        self.audio_sub = self.create_subscription(
            String,
            self.audio_topic,
            self.audio_callback,
            10,
        )

        self.get_logger().info(
            f'[AUDIO_ALERT] Monitoring {self.audio_topic} for phrase "{self.trigger_phrase}"'
        )

    def _load_model(self, model_path_param: str) -> Optional['Model']:
        if Model is None:
            self.get_logger().error('[AUDIO_ALERT] Python package "vosk" is not installed.')
            return None

        candidate_paths = []
        if model_path_param:
            candidate_paths.append(model_path_param)

        env_model_path = os.getenv('VOSK_MODEL_PATH', '')
        if env_model_path:
            candidate_paths.append(env_model_path)

        candidate_paths.extend([
            '/usr/share/vosk/model',
            '/usr/local/share/vosk/model',
            os.path.expanduser('~/models/vosk/model'),
        ])

        for path in candidate_paths:
            resolved = os.path.expanduser(path)
            if os.path.isdir(resolved):
                try:
                    self.get_logger().info(f'[AUDIO_ALERT] Loading Vosk model from {resolved}')
                    return Model(resolved)
                except Exception as exc:
                    self.get_logger().warn(
                        f'[AUDIO_ALERT] Failed to load model at {resolved}: {exc}'
                    )

        self.get_logger().error(
            '[AUDIO_ALERT] No valid Vosk model directory found. '
            'Set parameter model_path or environment variable VOSK_MODEL_PATH.'
        )
        return None

    def _ensure_recognizer(self, sample_rate: int) -> bool:
        if self.model is None or KaldiRecognizer is None:
            return False

        if self.recognizer is not None and self.recognizer_sample_rate == sample_rate:
            return True

        try:
            self.recognizer = KaldiRecognizer(self.model, float(sample_rate))
            self.recognizer_sample_rate = sample_rate
            return True
        except Exception as exc:
            self.get_logger().error(
                f'[AUDIO_ALERT] Could not initialize recognizer at {sample_rate}Hz: {exc}'
            )
            self.recognizer = None
            self.recognizer_sample_rate = None
            return False

    def _normalize_text(self, text: str) -> str:
        lowered = text.lower().strip()
        cleaned = re.sub(r'[^a-z0-9 ]+', ' ', lowered)
        return ' '.join(cleaned.split())

    def _should_alert(self, transcript: str) -> bool:
        normalized = self._normalize_text(transcript)
        return bool(normalized) and self.trigger_phrase in normalized

    def _publish_alert(self, transcript: str):
        now_sec = self.get_clock().now().nanoseconds / 1e9
        if now_sec - self.last_alert_time_sec < self.cooldown_seconds:
            return

        self.last_alert_time_sec = now_sec
        payload = {
            'alert_type': 'audio_help_request',
            'trigger_phrase': self.trigger_phrase,
            'transcript': transcript,
            'timestamp_sec': now_sec,
            'message': 'Audio help request detected',
        }

        msg = String()
        msg.data = json.dumps(payload)
        self.alert_pub.publish(msg)
        self.get_logger().warn(
            f'[AUDIO_ALERT] Trigger phrase detected in transcript: "{transcript}"'
        )

    def audio_callback(self, msg: String):
        if self.model is None:
            return

        try:
            payload = json.loads(msg.data)
            sample_rate = int(payload.get('sample_rate', 16000))
            raw_audio = base64.b64decode(payload.get('data', ''), validate=False)
        except Exception as exc:
            self.get_logger().warn(f'[AUDIO_ALERT] Invalid audio payload: {exc}')
            return

        if not raw_audio or not self._ensure_recognizer(sample_rate):
            return

        try:
            accepted = self.recognizer.AcceptWaveform(raw_audio)
            if not accepted:
                return

            result = json.loads(self.recognizer.Result())
            transcript = result.get('text', '').strip()
            if self._should_alert(transcript):
                self._publish_alert(transcript)
        except Exception as exc:
            self.get_logger().error(f'[AUDIO_ALERT] Recognition failed: {exc}')


def main(args=None):
    rclpy.init(args=args)
    node = AudioAlertMonitor()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()