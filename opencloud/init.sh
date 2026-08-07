#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

mkdir -p $DIRNAME/config $DIRNAME/data $DIRNAME/collabora

# Generate an RSA key pair for Collabora's WOPI proof signing. Without this
# Collabora skips proof headers, and OpenCloud's collaboration service then
# returns 500 ("Invalid timestamp") on every WOPI request.
if [ ! -f "$DIRNAME/collabora/proof_key" ]; then
    ssh-keygen -t rsa -b 2048 -N "" -m PEM -f "$DIRNAME/collabora/proof_key"
    # Collabora runs as a non-root user inside the container and can't read
    # ssh-keygen's default 0600 file (owned by the host user that ran init).
    chmod 644 "$DIRNAME/collabora/proof_key"
fi

# Render CSP config: allow the OIDC issuer and Collabora origins in
# connect-src/frame-src/form-action/img-src.
OIDC_ORIGIN=$(echo "$OIDC_ISSUER_URL" | awk -F/ '{print $1"//"$3}')
export OIDC_ORIGIN COLLABORA_FQDN
envsubst < $DIRNAME/csp.yaml.template > $DIRNAME/config/csp.yaml

docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d
