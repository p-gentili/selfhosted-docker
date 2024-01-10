#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

docker compose -f $COMPOSE down -v
docker compose -f $COMPOSE pull
docker compose -f $COMPOSE create
docker start immich_postgres

DUMP="$DIRNAME/dump.sql.gz"
if [[ -e $DUMP ]]; then
    echo "Restoring Immich DB backup..."
    sleep 10    # Wait for Postgres server to start up
    gunzip < $DUMP | docker exec -i immich_postgres psql -U postgres -d immich    # Restore Backup
fi

docker compose -f $COMPOSE up -d
