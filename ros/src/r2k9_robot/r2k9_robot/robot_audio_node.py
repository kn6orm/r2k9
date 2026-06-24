#!/usr/bin/env python3
import base64
import json
import subprocess
import threading
import time

import rclpy
from rclpy.node import Node
from std_msgs.msg import String


class RobotAudioNode(Node):
    def __init__(self):
        super().__init__('robot_audio_node')

        self.declare_parameter('audio_device', 'default')
        self.declare_parameter('sample_rate', 16000)
        self.declare_parameter('channels', 1)
        self.declare_parameter('chunk_size', 4096)

        self.audio_device = str(self.get_parameter('audio_device').value or 'default')
        self.sample_rate = int(self.get_parameter('sample_rate').value)
        self.channels = max(1, int(self.get_parameter('channels').value))
        self.chunk_size = max(2, int(self.get_parameter('chunk_size').value))
        if self.chunk_size % 2 != 0:
            self.chunk_size -= 1

        self.audio_pub = self.create_publisher(String, '/audio/web', 10)
        self._stop_event = threading.Event()
        self._process = None
        self._thread = threading.Thread(target=self._capture_loop, daemon=True)
        self._thread.start()

        self.get_logger().info(
            f"[AUDIO_INIT] Robot audio node started device={self.audio_device} rate={self.sample_rate} channels={self.channels} chunk_size={self.chunk_size}"
        )

    def _terminate_process(self):
        if self._process is None:
            return

        try:
            self._process.terminate()
            self._process.wait(timeout=2.0)
        except Exception:
            try:
                self._process.kill()
            except Exception:
                pass
        finally:
            self._process = None

    def _capture_loop(self):
        command = [
            'arecord',
            '-q',
            '-D',
            self.audio_device,
            '-f',
            'S16_LE',
            '-c',
            str(self.channels),
            '-r',
            str(self.sample_rate),
            '-t',
            'raw',
        ]

        while rclpy.ok() and not self._stop_event.is_set():
            try:
                self.get_logger().info(f"[AUDIO_CAPTURE] Starting arecord: {' '.join(command)}")
                self._process = subprocess.Popen(
                    command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    bufsize=0,
                )

                if self._process.stdout is None:
                    raise RuntimeError('arecord stdout was not available')

                chunk_index = 0
                while rclpy.ok() and not self._stop_event.is_set():
                    raw_audio = self._process.stdout.read(self.chunk_size)
                    if not raw_audio:
                        break

                    payload = {
                        'format': 'pcm_s16le',
                        'sample_rate': self.sample_rate,
                        'channels': self.channels,
                        'chunk_size': len(raw_audio),
                        'chunk_index': chunk_index,
                        'data': base64.b64encode(raw_audio).decode('ascii'),
                    }
                    msg = String()
                    msg.data = json.dumps(payload)
                    self.audio_pub.publish(msg)
                    chunk_index += 1

                self._terminate_process()
                if self._stop_event.is_set() or not rclpy.ok():
                    break

                self.get_logger().warn(
                    '[AUDIO_CAPTURE] Audio capture ended unexpectedly; restarting in 1 second'
                )
                time.sleep(1.0)
            except FileNotFoundError:
                self.get_logger().error(
                    '[AUDIO_ERROR] arecord was not found. Install alsa-utils on the robot.'
                )
                break
            except Exception as exc:
                self.get_logger().error(f'[AUDIO_ERROR] {exc}')
                self._terminate_process()
                if self._stop_event.is_set() or not rclpy.ok():
                    break
                time.sleep(1.0)

    def destroy_node(self):
        self._stop_event.set()
        self._terminate_process()
        if self._thread.is_alive():
            self._thread.join(timeout=2.0)
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = RobotAudioNode()
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
