#!/bin/bash
#
# Installs Frigate's Home Assistant integration into
# ../homeassistant/config/custom_components/frigate, which is what HACS would
# do. Re-run with a newer version to upgrade, then restart Home Assistant.
#
# Usage: ./install-ha-integration.sh [version]    (default below)

set -e

VERSION=${1:-v5.15.7}
DIRNAME=$(dirname "$(realpath "$0")")
HA_CONFIG=$(realpath "$DIRNAME/../homeassistant/config")

if [ ! -d "$HA_CONFIG" ]; then
    echo "$HA_CONFIG not found: set up Home Assistant first." >&2
    exit 1
fi

# Home Assistant's config folder is owned by root (the container writes it),
# so do the copy from a throwaway container instead of needing sudo.
docker run --rm -v "$HA_CONFIG:/ha" alpine sh -euc "
    wget -qO- https://github.com/blakeblackshear/frigate-hass-integration/archive/refs/tags/$VERSION.tar.gz \
        | tar -xz -C /tmp
    mkdir -p /ha/custom_components
    rm -rf /ha/custom_components/frigate
    cp -r /tmp/frigate-hass-integration-*/custom_components/frigate /ha/custom_components/
    grep '\"version\"' /ha/custom_components/frigate/manifest.json
"

echo "Installed. Now run: docker restart homeassistant"
