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

# Build compose command based on GPU setting
COMPOSE_CMD="docker compose -f docker-compose.yaml"
if [ "$USE_GPU" = "true" ]; then
    COMPOSE_CMD="$COMPOSE_CMD -f docker-compose.nvidia.yaml"
fi

# Check if the container is already running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '$CONTAINER_NAME' is already running. Executing bash..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
else
    echo "Starting container '$CONTAINER_NAME'..."
    if [ "$USE_GPU" = "true" ]; then
        echo "GPU support: enabled"
    else
        echo "GPU support: disabled"
    fi
    $COMPOSE_CMD run --rm app /bin/bash
fi
