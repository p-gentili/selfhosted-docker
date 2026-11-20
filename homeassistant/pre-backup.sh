#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

# The recorder keeps a live SQLite database (home-assistant_v2.db) in
# ./config, which a file-level copy only captures consistently while stopped.
docker compose -f $COMPOSE stop homeassistant
