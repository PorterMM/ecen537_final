#!/usr/bin/env bash
set -eo pipefail
# shellcheck source=docker/setup.bash
source /usr/local/share/ecen537/setup.bash

python3 - "$@" <<'PY'
import os
import selectors
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import cv2
import cv_bridge
import matplotlib
import numpy
import rclpy
import scipy
from ament_index_python.packages import get_package_share_directory

assert os.getuid() != 0, 'Container should run as the non-root developer user'
expected_ids = tuple(map(int, sys.argv[1:])) if len(sys.argv) > 1 else (os.getuid(), os.getgid())
assert (os.getuid(), os.getgid()) == expected_ids, 'Container UID/GID does not match the host; rebuild the image'
assert hasattr(cv2, 'aruco'), 'OpenCV ArUco support is missing'
for package in (
    'rviz2', 'moveit_ros_move_group', 'moveit_servo', 'controller_manager',
    'joint_trajectory_controller', 'gz_ros2_control', 'ros_gz_sim', 'ros_gz_bridge',
    'tf2_ros', 'tf2_tools', 'xacro', 'robot_state_publisher',
    'joint_state_publisher_gui', 'image_transport', 'camera_calibration',
    'image_proc', 'cv_bridge', 'demo_nodes_cpp', 'demo_nodes_py',
):
    get_package_share_directory(package)
subprocess.run(['gz', 'sim', '--versions'], check=True)
print(f'Dependencies: OK (OpenCV {cv2.__version__}, ArUco available)', flush=True)

# A real publish/subscribe round trip, isolated from the user's chatter topic.
topic = f'/ecen537_smoke_{os.getpid()}'
processes = []
try:
    talker = subprocess.Popen(
        ['ros2', 'run', 'demo_nodes_cpp', 'talker', '--ros-args', '-r', f'chatter:={topic}'],
        stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, start_new_session=True,
    )
    processes.append(talker)
    listener = subprocess.Popen(
        ['ros2', 'run', 'demo_nodes_cpp', 'listener', '--ros-args', '-r', f'chatter:={topic}'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True,
    )
    processes.append(listener)
    with selectors.DefaultSelector() as ready:
        ready.register(listener.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + 30
        received = False
        recent_output = b''
        while time.monotonic() < deadline:
            if talker.poll() is not None or listener.poll() is not None:
                raise RuntimeError('ROS demo process exited before receiving a message')
            for key, _ in ready.select(timeout=0.5):
                recent_output = (recent_output + os.read(key.fd, 4096))[-8192:]
                if b'I heard: [Hello World:' in recent_output:
                    received = True
                    break
            if received:
                break
        if not received:
            raise RuntimeError('ROS messaging timed out after 30 seconds: '
                               + recent_output.decode(errors='replace'))
finally:
    for process in processes:
        try:
            os.killpg(process.pid, signal.SIGINT)
        except ProcessLookupError:
            pass
    for process in processes:
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    if 'listener' in locals():
        listener.stdout.close()
print('ROS demo messaging: OK', flush=True)

# Build away from the real workspace so existing application packages are untouched.
with tempfile.TemporaryDirectory(prefix='ecen537-build-') as directory:
    root = Path(directory)
    (root / 'src').mkdir()
    subprocess.run([
        'ros2', 'pkg', 'create', '--build-type', 'ament_cmake', '--license', 'Apache-2.0',
        '--node-name', 'sanity_node', '--destination-directory', str(root / 'src'),
        'ecen537_env_sanity', '--dependencies', 'rclcpp',
    ], check=True, cwd=root)
    subprocess.run(['colcon', 'build', '--symlink-install'], check=True, cwd=root, timeout=120)
    assert (root / 'install' / 'setup.bash').is_file()
with tempfile.NamedTemporaryFile(prefix='.ownership-check-', dir=os.environ['ROS_WS']) as owned:
    assert os.stat(owned.name).st_uid == expected_ids[0]
print(f'Temporary workspace build and bind-mount write: OK (UID:GID {os.getuid()}:{os.getgid()})')
print('Smoke checks passed. Gazebo/RViz GUI rendering is a separate manual check.')
PY
