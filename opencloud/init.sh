#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

mkdir -p $DIRNAME/config $DIRNAME/data

# Render CSP config: allow the OIDC issuer origin in connect-src/frame-src/form-action/img-src.
OIDC_ORIGIN=$(echo "$OIDC_ISSUER_URL" | awk -F/ '{print $1"//"$3}')
export OIDC_ORIGIN
envsubst < $DIRNAME/csp.yaml.template > $DIRNAME/config/csp.yaml

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
