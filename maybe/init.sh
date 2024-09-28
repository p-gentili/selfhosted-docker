#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

docker compose -f $COMPOSE down -v
docker compose -f $COMPOSE pull
docker compose -f $COMPOSE create
docker start maybe_postgres

DUMP="$DIRNAME/dump.sql.gz"
if [[ -e $DUMP ]]; then
    echo "Restoring Maybe DB backup..."
    sleep 10    # Wait for Postgres server to start up
    gunzip < $DUMP | docker exec -i maybe_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB    # Restore Backup
fi

docker compose -f $COMPOSE up -d
