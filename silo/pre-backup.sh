#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

# ./config holds a live PostgreSQL cluster, which a file-level copy can only
# capture consistently while it is stopped.
docker compose -f $COMPOSE stop silo
