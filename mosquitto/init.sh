#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
IMAGE=eclipse-mosquitto:2

if [ ! -f "$DIRNAME/.env" ]; then
    echo "Missing $DIRNAME/.env: copy .env.sample and set MQTT_PASSWORD." >&2
    exit 1
fi
. "$DIRNAME/.env"
if [ -z "$MQTT_USER" ] || [ -z "$MQTT_PASSWORD" ] || [ "$MQTT_PASSWORD" = "changeme" ]; then
    echo "Set MQTT_USER and MQTT_PASSWORD in .env (openssl rand -hex 24)." >&2
    exit 1
fi

mkdir -p "$DIRNAME/config" "$DIRNAME/data"
chown 1000:1000 "$DIRNAME/config" "$DIRNAME/data" 2>/dev/null || true

# Rebuild the password file from .env on every run, as the same user the
# broker runs as.
docker run --rm --user 1000:1000 -v "$DIRNAME/config:/auth" $IMAGE \
    mosquitto_passwd -b -c /auth/passwd "$MQTT_USER" "$MQTT_PASSWORD"

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
