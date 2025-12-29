#!/bin/bash
set -ex

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

exec docker compose            \
       $FEATURE_BASIC          \
       $FEATURE_WATCHTOWER     \
       $FEATURE_LOCAL          \
       "$@"
