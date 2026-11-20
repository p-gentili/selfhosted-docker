#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
STORAGE=/media/external/frigate

if [ ! -f "$DIRNAME/.env" ]; then
    echo "Missing $DIRNAME/.env: copy .env.sample and fill it in." >&2
    exit 1
fi
if grep -q '=changeme$\|192.168.68.x' "$DIRNAME/.env"; then
    echo "$DIRNAME/.env still has sample values." >&2
    exit 1
fi

# Without the dedicated filesystem, recordings would land on the shared
# external disk and fill it, so refuse to start.
if ! mountpoint -q "$STORAGE"; then
    echo "$STORAGE is not mounted. Run: sudo $DIRNAME/setup-storage.sh <size in GB>" >&2
    exit 1
fi

mkdir -p "$DIRNAME/config"
if [ ! -f "$DIRNAME/config/config.yml" ]; then
    cp "$DIRNAME/config.template.yml" "$DIRNAME/config/config.yml"
fi

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
