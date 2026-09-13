#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

# The SQLite store under ./data is written in place with no transactional
# guarantees across a filesystem snapshot, so stop the container first.
docker compose -f $COMPOSE stop agendav
