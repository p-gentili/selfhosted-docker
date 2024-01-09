#!/bin/bash
docker exec -t immich_postgres pg_dumpall -c -U postgres | gzip > "dump.sql.gz"
