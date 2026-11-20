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

# Passwords end up inside rtsp:// URLs (where `#`, `@`, `/`... break the
# URL) and pass through compose (which mangles `$`): letters and digits only.
BAD=$(grep -E '^FRIGATE_[A-Z_]*PASSWORD=' "$DIRNAME/.env" | grep -E '=.*[^A-Za-z0-9]' | cut -d= -f1 || true)
if [ -n "$BAD" ]; then
    echo "These passwords in .env may only contain letters and digits:" $BAD >&2
    echo "Change them at the source too (Tapo app, ../mosquitto/.env)." >&2
    exit 1
fi

# Recordings go on the external drive; don't create the folder on the root
# disk if it isn't mounted.
if ! mountpoint -q /media/external; then
    echo "/media/external is not mounted." >&2
    exit 1
fi

mkdir -p "$DIRNAME/config" "$STORAGE"
if [ ! -f "$DIRNAME/config/config.yml" ]; then
    cp "$DIRNAME/config.template.yml" "$DIRNAME/config/config.yml"
fi

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
