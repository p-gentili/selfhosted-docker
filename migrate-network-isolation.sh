#!/bin/bash
#
# One-time migration from the shared `frontend` docker network to per-stack
# `caddy_<stack>` networks. Run this on the host once, after pulling the
# branch that introduces network isolation.
#
# It preserves volumes (no `down -v`): containers are stopped, removed, and
# recreated bound to the new networks. Bind mounts and named volumes survive.
#
# Per-stack downtime: ~30s. Total runtime: ~10-15 min.

set -e

DIRNAME=$(dirname "$(realpath "$0")")
cd "$DIRNAME"

NETWORKS=(
    caddy_audiobookshelf
    caddy_authentik
    caddy_calibre
    caddy_changedetection
    caddy_freshrss
    caddy_ghostfolio
    caddy_gotify
    caddy_homeassistant
    caddy_immich
    caddy_jellyfin
    caddy_komga
    caddy_linkding
    caddy_mealie
    caddy_nextcloud
    caddy_opencloud
    caddy_paperless
    caddy_syncthing
    caddy_transmission
    caddy_vaultwarden
    caddy_wallos
)

STACKS=(
    audiobookshelf
    authentik
    calibre-web-automated
    changedetection-io
    freshrss
    ghostfolio
    gotify
    homeassistant
    immich
    jellyfin
    komga
    linkding
    mealie
    nextcloud
    opencloud
    paperlessngx
    syncthing
    transmission
    vaultwarden
    wallos
)

echo "==> Creating new networks"
for net in "${NETWORKS[@]}"; do
    sudo docker network create "$net" 2> /dev/null || true
done

echo "==> Recreating application stacks on new networks (volumes preserved)"
for stack in "${STACKS[@]}"; do
    echo "  - $stack"
    sudo docker compose -f "$stack/docker-compose.yml" down
    sudo docker compose -f "$stack/docker-compose.yml" up -d
done

echo "==> Recreating caddy on new networks"
sudo docker compose -f caddy/docker-compose.yml down
sudo docker compose -f caddy/docker-compose.yml up -d

echo "==> Removing the old shared 'frontend' network"
sudo docker network rm frontend 2> /dev/null || true

echo
echo "Done. Verify with:"
echo "  docker network ls | grep caddy_"
echo "  docker inspect caddy --format '{{range \$k,\$v := .NetworkSettings.Networks}}{{\$k}} {{end}}'"
echo
echo "If you had PROXY_IP=<caddy-ip> in nextcloud/.env, update it to"
echo "PROXY_IP=172.16.0.0/12 to trust caddy across any docker subnet."
