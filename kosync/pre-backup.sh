#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

# Stop the container so bundled Redis flushes its snapshot to ./data/redis,
# giving a consistent on-disk copy for the directory backup.
docker compose -f $COMPOSE stop
