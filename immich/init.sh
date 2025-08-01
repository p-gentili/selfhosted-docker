#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

docker compose -f $COMPOSE down -v
rm -rf $DB_DATA_LOCATION
docker compose -f $COMPOSE pull
docker compose -f $COMPOSE create
docker start immich_postgres

DUMP="$DIRNAME/dump.sql.gz"
if [[ -e $DUMP ]]; then
    echo "Restoring Immich DB backup..."
    sleep 10    # Wait for Postgres server to start up
    gunzip --stdout $DUMP \
	    | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
	    | docker exec -i immich_postgres psql --dbname=$DB_DATABASE_NAME --username=$DB_USERNAME  # Restore Backup
fi

docker compose -f $COMPOSE up -d
