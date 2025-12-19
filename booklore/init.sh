#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

docker compose -f $COMPOSE down -v
docker compose -f $COMPOSE up -d

BACKUP=$DIRNAME/dump.bak
if [[ -e $BACKUP ]]; then
    echo "Restoring Booklore DB backup..."
    sleep 15
    docker exec -i booklore-db sh -c 'exec mariadb -uroot -p"$MYSQL_ROOT_PASSWORD"' < $BACKUP
fi
