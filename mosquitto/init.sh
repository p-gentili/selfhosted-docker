#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
IMAGE=eclipse-mosquitto:2

if [ ! -f "$DIRNAME/.env" ]; then
    echo "Missing $DIRNAME/.env: copy .env.sample and set the passwords." >&2
    exit 1
fi

# Each MQTT_USER_<name>=<password> line in .env is one account.
ACCOUNTS=$(grep -E '^MQTT_USER_[A-Za-z0-9_-]+=' "$DIRNAME/.env" || true)
if [ -z "$ACCOUNTS" ]; then
    echo "No MQTT_USER_<name>=<password> lines in .env." >&2
    exit 1
fi
if echo "$ACCOUNTS" | grep -qE '=(changeme)?$'; then
    echo "Some MQTT_USER_ lines in .env are empty or still 'changeme'." >&2
    exit 1
fi

mkdir -p "$DIRNAME/config" "$DIRNAME/data"
chown 1000:1000 "$DIRNAME/config" "$DIRNAME/data" 2>/dev/null || true

# Rebuild the password file from scratch on every run, so accounts removed
# from .env lose access. It runs as the same user the broker runs as.
rm -f "$DIRNAME/config/passwd"
touch "$DIRNAME/config/passwd"
chown 1000:1000 "$DIRNAME/config/passwd" 2>/dev/null || true
chmod 600 "$DIRNAME/config/passwd"
while IFS='=' read -r KEY PASSWORD; do
    USER=${KEY#MQTT_USER_}
    docker run --rm --user 1000:1000 -v "$DIRNAME/config:/auth" $IMAGE \
        mosquitto_passwd -b /auth/passwd "$USER" "$PASSWORD"
done <<< "$ACCOUNTS"

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
