#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR" || exit 1

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Default container name if not set
CONTAINER_NAME="${CONTAINER_NAME:-ros2-docker-template}"

# Address the per-platform service selected by install.sh.
COMPOSE_PROFILE="${COMPOSE_PROFILE:-linux}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-$COMPOSE_PROFILE}"
COMPOSE_CMD="docker compose --profile $COMPOSE_PROFILE"

# Check if a container is already running (exact match or compose run pattern)
RUNNING_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E "^${CONTAINER_NAME}(-.*-run-.*)?$" | head -n 1)

TTY_FLAG=""
[ -t 0 ] && TTY_FLAG="-it"
if [ -n "$RUNNING_CONTAINER" ]; then
    echo "Container '$RUNNING_CONTAINER' is already running. Executing bash..."
    if [ $# -eq 0 ]; then
        docker exec $TTY_FLAG "$RUNNING_CONTAINER" bash -c "source /entrypoint.sh && exec bash"
    else
        docker exec $TTY_FLAG "$RUNNING_CONTAINER" bash -c "source /entrypoint.sh && $*"
    fi
else
    echo "Starting container '$CONTAINER_NAME' (profile: $COMPOSE_PROFILE)..."
    if [ $# -eq 0 ]; then
        $COMPOSE_CMD run --rm "$COMPOSE_SERVICE" /bin/bash
    else
        # Don't use "bash -c" wrapper - let entrypoint handle environment and run command directly
        $COMPOSE_CMD run --rm "$COMPOSE_SERVICE" "$@"
    fi
fi
