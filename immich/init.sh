#!/bin/bash
docker compose down -v
docker compose pull
docker compose create
docker start immich_postgres

DUMP="dump.sql.gz"
if [[ -e $DUMP ]]; then
    echo "Restoring Immich DB backup..."
    sleep 10    # Wait for Postgres server to start up
    gunzip < $DUMP | docker exec -i immich_postgres psql -U postgres -d immich    # Restore Backup
fi

docker compose up -d
