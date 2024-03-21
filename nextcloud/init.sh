#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

docker compose -f $COMPOSE down -v
docker compose -f $COMPOSE up -d

BACKUP=$DIRNAME/dump.bak
if [[ -e $BACKUP ]]; then
    echo "Restoring Nextcloud DB backup..."
    sleep 15
    docker exec -i nextcloud-db sh -c 'exec mariadb -uroot -p"$MYSQL_ROOT_PASSWORD"' < $BACKUP
fi

sudo chown -R www-data:www-data $DIRNAME/nextcloud/*
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
