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

# The MQTT password must match ../mosquitto/.env, which only allows letters
# and digits.
if grep -E '^FRIGATE_MQTT_PASSWORD=' "$DIRNAME/.env" | grep -qE '=.*[^A-Za-z0-9]'; then
    echo "FRIGATE_MQTT_PASSWORD may only contain letters and digits." >&2
    exit 1
fi

# The Tapo password may hold any symbol except `$`, which compose rewrites.
# ONVIF takes it as-is; the rtsp:// URLs need it percent-encoded (a `#`
# would end the URL), so write that form to .env.generated for compose.
TAPO_PASSWORD=$(grep -E '^FRIGATE_TAPO_PASSWORD=' "$DIRNAME/.env" | cut -d= -f2-)
if [[ "$TAPO_PASSWORD" == *'$'* ]]; then
    echo "FRIGATE_TAPO_PASSWORD can't contain \$: compose would rewrite it." >&2
    exit 1
fi
(
    umask 077
    printf 'FRIGATE_TAPO_PASSWORD_URL=%s\n' "$(python3 -c \
        'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' \
        "$TAPO_PASSWORD")" > "$DIRNAME/.env.generated"
)

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
