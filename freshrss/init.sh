#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

docker compose -f $COMPOSE down -v
docker compose -f $COMPOSE pull
docker compose -f $COMPOSE create
docker start freshrss-db

DUMP="$DIRNAME/dump.sql.gz"
if [[ -e $DUMP ]]; then
    echo "Restoring FreshRSS DB backup..."
    sleep 10    # Wait for Postgres server to start up
    gunzip < $DUMP | docker exec -i freshrss-db psql -U $DB_USER -d $DB_BASE    # Restore Backup
fi

docker compose -f $COMPOSE up -d
