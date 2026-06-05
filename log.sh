#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR" || exit 1

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

CONTAINER_NAME="${CONTAINER_NAME:-ros2-docker-template}"
USE_SERVICE="${USE_SERVICE:-false}"

if [ "$USE_SERVICE" = "true" ]; then
    sudo journalctl -u "${CONTAINER_NAME}" -f
else
    echo "USE_SERVICE is not enabled. Use 'docker compose logs -f' or connect to the container directly."
fi
