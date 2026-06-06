#!/bin/bash
# Basic entrypoint for ROS / Colcon Docker containers

# Source ROS 2
source /opt/ros/${ROS_DISTRO}/setup.bash

# Source the base workspace, if built
if [ -f /workspaces/base_ws/install/setup.bash ]
then
    source /workspaces/base_ws/install/setup.bash
fi

# Source the overlay workspace, if built. If not, build it.
if [ -f /workspaces/shared_ws/install/setup.bash ]
then
    source /workspaces/shared_ws/install/setup.bash
else
    echo "Shared workspace not found. Building shared workspace..."
    if (cd /workspaces/shared_ws && colcon build); then
        source /workspaces/shared_ws/install/setup.bash
        echo "✓ Shared workspace built and sourced"
    else
        echo "⚠ Shared workspace build failed"
    fi
fi

# Middleware selection. Honors RMW_IMPLEMENTATION from the environment
# (set via docker-compose / .env). Defaults to CycloneDDS if unset.
# NOTE: micro-ROS agent in this image is built with FastDDS, so use
# rmw_fastrtps_cpp in .env if you need it to discover micro-ROS clients.
export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}

# Force libcamera to use the RPi-fork IPA modules we built at /usr/local
# rather than the ones from ros-jazzy-libcamera (Noble upstream), which are
# ABI-incompatible with our pipeline handlers.
export LIBCAMERA_IPA_MODULE_PATH=/usr/local/lib/aarch64-linux-gnu/libcamera/ipa

exec "$@"