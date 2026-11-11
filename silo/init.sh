#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml

# Check SECRET_KEY as compose interpolates it, not as bash would: sourcing
# .env would run a literal `$(openssl rand ...)`, while compose passes that
# text through as-is and Silo then crash-loops on a 26-char key.
SECRET_KEY=$(docker compose -f $COMPOSE config 2>/dev/null \
    | sed -n 's/^ *SECRET_KEY: *//p' | tr -d "\"'")
if [ "${#SECRET_KEY}" -lt 32 ] || [ "$SECRET_KEY" = "changeme" ]; then
    echo "SECRET_KEY in .env is unset, the sample value, or under 32 chars." >&2
    echo "Paste the OUTPUT of: openssl rand -base64 48" >&2
    exit 1
fi

mkdir -p "$DIRNAME/config" "$DIRNAME/transcode" "$DIRNAME/download-artifacts"

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
