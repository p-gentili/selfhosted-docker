#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" = "changeme" ]; then
    echo "SECRET_KEY is unset or still the sample value in .env." >&2
    echo "Generate one with: openssl rand -base64 48" >&2
    exit 1
fi

mkdir -p "$DIRNAME/config" "$DIRNAME/transcode" "$DIRNAME/download-artifacts"

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
