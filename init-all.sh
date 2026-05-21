#!/bin/bash

# Each caddy-proxied stack lives on its own dedicated docker network shared
# only with caddy, so a compromise of one application cannot reach the others'
# internal ports. Pre-create the networks before bringing stacks up.
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
for net in "${NETWORKS[@]}"; do
    sudo docker network create "$net" 2> /dev/null
done

sudo find . -name "init.sh" -exec {} \;
