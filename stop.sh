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
    SERVICE_NAME="${CONTAINER_NAME}.service"
    if systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1 \
       && systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Stopping $SERVICE_NAME..."
        sudo systemctl stop "$SERVICE_NAME"
    fi
fi

COMPOSE_CMD="docker compose -f docker-compose.yaml"
if [ "$USE_GPU" = "true" ]; then
    COMPOSE_CMD="$COMPOSE_CMD -f docker-compose.nvidia.yaml"
fi

echo "Stopping any existing '$CONTAINER_NAME' containers..."
$COMPOSE_CMD down --remove-orphans

# `docker compose down` returns before the daemon has finished tearing
# containers down, so the follow-up `docker rm -f` can race against
# in-progress removals ("removal already in progress"). Poll until the
# matching containers are gone, then force-remove whatever's left as a
# belt-and-suspenders for orphans compose didn't know about.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    mapfile -t STALE < <(docker ps -aq --filter "name=^${CONTAINER_NAME}(-app-run-.*)?$")
    [ ${#STALE[@]} -eq 0 ] && break
    sleep 1
done
if [ ${#STALE[@]} -gt 0 ]; then
    docker rm -f "${STALE[@]}" >/dev/null 2>&1 || true
fi
