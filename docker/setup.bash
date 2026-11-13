# Sourced by the entrypoint and each interactive Bash shell.
# These files are provided by ROS and colcon inside the container.
# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
if [[ -f /workspaces/ecen537_final/ros2_ws/install/setup.bash ]]; then
    # shellcheck disable=SC1091
    source /workspaces/ecen537_final/ros2_ws/install/setup.bash
fi
