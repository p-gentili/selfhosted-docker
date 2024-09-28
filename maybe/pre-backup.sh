#!/bin/bash

set -e 
DIRNAME=$(dirname "$(realpath "$0")")
source $DIRNAME/.env

docker exec -t maybe_postgres pg_dumpall -c -U $POSTGRES_USER | gzip > "$DIRNAME/dump.sql.gz"
