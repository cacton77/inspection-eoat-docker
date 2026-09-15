#!/bin/bash
# Entrypoint for the ROS / colcon container.
#
# This file does two jobs. Run as the ENTRYPOINT (container start) it builds the
# shared workspace, sets up the environment and execs the command. Sourced --
# by ~/.bashrc in the image, and by connect.sh's `docker exec` shells -- it only
# sets up the environment. Building on the sourced path would start a colcon
# build in every new shell, concurrently with the running launch, rewriting
# install/ underneath nodes that have it loaded.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ENTRYPOINT_MODE=exec
else
    ENTRYPOINT_MODE=source
fi

SHARED_WS=/workspaces/shared_ws

# Source ROS 2
source /opt/ros/${ROS_DISTRO}/setup.bash

# Source the base workspace, if built
if [ -f /workspaces/base_ws/install/setup.bash ]
then
    source /workspaces/base_ws/install/setup.bash
fi

if [ "$ENTRYPOINT_MODE" = exec ]; then
    # build/, install/ and log/ are bind-mounted from the host, so they outlive
    # the --rm container and this is an incremental build: CMake packages find
    # their caches and object files, and rosidl only regenerates interfaces
    # whose .msg files actually changed.
    #
    # It runs on EVERY start. It used to run only when install/setup.bash was
    # missing, which was harmless while install/ died with the container -- but
    # with install/ persistent, that check would find the old setup.bash and
    # never build again, so source edits would silently stop taking effect.
    #
    # flock serialises concurrent starts (the service plus a manual connect.sh):
    # two colcon builds sharing one build/ tree corrupt it.
    mkdir -p "$SHARED_WS/build"
    echo "Building shared workspace (incremental)..."
    if (cd "$SHARED_WS" && flock "$SHARED_WS/build/.colcon_build.lock" colcon build); then
        echo "✓ Shared workspace up to date"
    else
        echo "⚠ Shared workspace build FAILED. Continuing with the existing install/,"
        echo "  which may be stale or partially updated. Fix the build and restart."
    fi
fi

# Source the overlay workspace, if built
if [ -f "$SHARED_WS/install/setup.bash" ]
then
    source "$SHARED_WS/install/setup.bash"
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

if [ "$ENTRYPOINT_MODE" = exec ]; then
    exec "$@"
fi
