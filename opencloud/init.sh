#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

mkdir -p $DIRNAME/config $DIRNAME/data

# Derive a few values from the FQDNs so the compose file stays DRY.
OIDC_ORIGIN=$(echo "$OIDC_ISSUER_URL" | awk -F/ '{print $1"//"$3}')
COLLABORA_HOST=$(echo "$COLLABORA_FQDN" | sed -E 's|^https?://||; s|/.*$||')
export OIDC_ORIGIN COLLABORA_HOST

# Render CSP config: allow the OIDC issuer origin in connect-src/frame-src/form-action/img-src.
envsubst < $DIRNAME/csp.yaml.template > $DIRNAME/config/csp.yaml

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
