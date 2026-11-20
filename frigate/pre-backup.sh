#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

# ./config holds Frigate's live SQLite database, which a file-level copy only
# captures consistently while it is stopped. Recordings are outside /srv.
docker compose -f $COMPOSE stop frigate
