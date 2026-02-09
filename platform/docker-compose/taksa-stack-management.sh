#!/bin/bash
#set -ex

. ./taksa.env

export COMPOSE_HTTP_TIMEOUT=300
dockercompose_dir=./compose-dir
# Disable watchtower for now
WATCHTOWER_ENABLED=no

FEATURE_BASIC=" -p $CONTROLLER_NAME_PREFIX                                    \
     -f $dockercompose_dir/docker-compose.taksa-base.yml"

FEATURE_WATCHTOWER=" -f $dockercompose_dir/docker-compose.taksa-watchtower.yml"
FEATURE_LOCAL=

if [ "_X$WATCHTOWER_ENABLED" = "_Xno" ]; then
    FEATURE_WATCHTOWER=
fi

if [ -f $dockercompose_dir/docker-compose.local.yml ]; then
    FEATURE_LOCAL=" -f $dockercompose_dir/docker-compose.local.yml"
fi

if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif docker-compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Error: Docker Compose not found on this system" >&2
    exit 1
fi

exec $DOCKER_COMPOSE_CMD       \
       $FEATURE_BASIC          \
       $FEATURE_WATCHTOWER     \
       $FEATURE_LOCAL          \
       "$@"
