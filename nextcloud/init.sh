#!/bin/bash
source .env

docker compose down -v
docker compose up -d

BACKUP=dump.bak
if [[ -e $BACKUP ]]; then
    echo "Restoring Nextcloud DB backup..."
    docker exec -i nextcloud-db mysql [--user nextcloud] [--password=$MYSQL_PASSWORD] nextcloud < $BACKUP
fi
