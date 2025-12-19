#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
source $DIRNAME/.env

docker exec booklore-db mariadb-dump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD" > "$DIRNAME/dump.bak"
