#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
source $DIRNAME/.env

docker exec -u www-data nextcloud php occ maintenance:mode --on
docker exec nextcloud-db mariadb-dump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD" > "$DIRNAME/dump.bak"
