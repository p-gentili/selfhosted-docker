#!/bin/bash

set -e 
DIRNAME=$(dirname "$(realpath "$0")")

docker exec -t immich_postgres pg_dumpall -c -U postgres | gzip > "$DIRNAME/dump.sql.gz"
