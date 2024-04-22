#!/bin/bash

set -e 
DIRNAME=$(dirname "$(realpath "$0")")
source $DIRNAME/.env

docker exec -t immich_postgres pg_dumpall -c -U $DB_USER | gzip > "$DIRNAME/dump.sql.gz"
