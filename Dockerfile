FROM ros:jazzy-ros-base-noble

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG DEV_UID=1000
ARG DEV_GID=1000

# Use Ubuntu/ROS binary packages together to keep cv_bridge and OpenCV compatible.
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        cmake \
        curl \
        gdb \
        git \
        less \
        libeigen3-dev \
        libgl1-mesa-dri \
        libopencv-dev \
        libopencv-contrib-dev \
        mesa-utils \
        nano \
        pkg-config \
        python3-colcon-common-extensions \
        python3-matplotlib \
        python3-numpy \
        python3-opencv \
        python3-pip \
        python3-pytest \
        python3-rosdep \
        python3-scipy \
        python3-setuptools \
        python3-vcstool \
        python3-venv \
        ros-jazzy-ament-lint-auto \
        ros-jazzy-ament-lint-common \
        ros-jazzy-camera-calibration \
        ros-jazzy-cv-bridge \
        ros-jazzy-demo-nodes-cpp \
        ros-jazzy-demo-nodes-py \
        ros-jazzy-desktop \
        ros-jazzy-gz-ros2-control \
        ros-jazzy-image-pipeline \
        ros-jazzy-image-transport-plugins \
        ros-jazzy-joint-state-publisher-gui \
        ros-jazzy-moveit \
        ros-jazzy-moveit-servo \
        ros-jazzy-robot-state-publisher \
        ros-jazzy-ros-gz \
        ros-jazzy-ros2-control \
        ros-jazzy-ros2-controllers \
        ros-jazzy-tf2-ros \
        ros-jazzy-tf2-tools \
        ros-jazzy-tf2-eigen \
        ros-jazzy-tf2-geometry-msgs \
        ros-jazzy-urdf \
        ros-jazzy-xacro \
        sudo \
        vim-tiny \
        xauth \
        x11-utils \
    && rm -rf /var/lib/apt/lists/*

# Noble images may already contain an ubuntu user with UID 1000.
# Resolve that image-local collision before creating the host-matching user.
RUN set -eu; \
    test "$DEV_UID" -gt 0; \
    test "$DEV_GID" -gt 0; \
    if getent passwd "$DEV_UID" >/dev/null; then \
        userdel "$(getent passwd "$DEV_UID" | cut -d: -f1)"; \
    fi; \
    if ! getent group "$DEV_GID" >/dev/null; then \
        groupadd --gid "$DEV_GID" developer; \
    fi; \
    useradd --no-log-init --uid "$DEV_UID" --gid "$DEV_GID" \
        --create-home --shell /bin/bash developer; \
    echo 'developer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/developer; \
    chmod 0440 /etc/sudoers.d/developer; \
    mkdir -p /workspaces/ecen537_final/ros2_ws/src; \
    chown -R "$DEV_UID:$DEV_GID" /workspaces /home/developer; \
    if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then rosdep init; fi

COPY docker/setup.bash /usr/local/share/ecen537/setup.bash
COPY docker/entrypoint.sh /usr/local/bin/ecen537-entrypoint
COPY docker/smoke.sh /usr/local/bin/ecen537-smoke
COPY docker/worlds/empty.sdf /opt/ecen537/worlds/empty.sdf
RUN chmod 0755 /usr/local/bin/ecen537-entrypoint /usr/local/bin/ecen537-smoke \
    && echo 'source /usr/local/share/ecen537/setup.bash' >> /home/developer/.bashrc

ENV HOME=/home/developer
ENV ROS_WS=/workspaces/ecen537_final/ros2_ws
USER developer
RUN rosdep update --rosdistro jazzy
WORKDIR /workspaces/ecen537_final/ros2_ws

ENTRYPOINT ["/usr/local/bin/ecen537-entrypoint"]
CMD ["sleep", "infinity"]
