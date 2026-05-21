#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

mkdir -p $DIRNAME/config $DIRNAME/data

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
