#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

if [ ! -f "$DIRNAME/.env" ]; then
    echo "Missing $DIRNAME/.env: copy .env.sample and fill it in." >&2
    exit 1
fi

PUID=$(sed -n 's/^PUID=//p' "$DIRNAME/.env"); PUID=${PUID:-1000}
PGID=$(sed -n 's/^PGID=//p' "$DIRNAME/.env"); PGID=${PGID:-1000}

# Jotty runs as PUID:PGID and cannot create its own folders, while init-all.sh
# runs this as root, so create them here and hand them over.
mkdir -p "$DIRNAME"/data/{users,checklists,notes,sharing,encryption} \
    "$DIRNAME/config" "$DIRNAME/cache"
chown -R "$PUID:$PGID" "$DIRNAME/data" "$DIRNAME/config" "$DIRNAME/cache"

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
