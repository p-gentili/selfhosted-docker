#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

docker compose -f $COMPOSE down -v
docker compose -f $COMPOSE up -d
