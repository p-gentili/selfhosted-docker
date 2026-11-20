#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

mkdir -p "$DIRNAME/config"

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
