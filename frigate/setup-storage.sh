#!/bin/bash
#
# Creates the fixed-size filesystem that caps Frigate's recordings.
#
# Frigate has no size limit of its own: it keeps video for the configured
# number of days, and only deletes early when the disk under /media/frigate
# is nearly full. Giving it a filesystem of its own (an ext4 image file on the
# external disk, loop-mounted at /media/external/frigate) makes that size the
# maximum, and keeps the rest of the external disk safe from it.
#
# Usage: sudo ./setup-storage.sh <size in GB>    e.g. sudo ./setup-storage.sh 200
# Run it once. To resize later, see the README.

set -e

SIZE_GB=$1
IMG=/media/external/frigate.img
MNT=/media/external/frigate

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 <size in GB>" >&2
    exit 1
fi
if ! [[ "$SIZE_GB" =~ ^[0-9]+$ ]] || [ "$SIZE_GB" -lt 10 ]; then
    echo "Usage: sudo $0 <size in GB, at least 10>" >&2
    exit 1
fi
if ! mountpoint -q /media/external; then
    echo "/media/external is not mounted." >&2
    exit 1
fi
if [ -e "$IMG" ]; then
    echo "$IMG already exists; not touching it." >&2
    exit 1
fi

fallocate -l "${SIZE_GB}G" "$IMG"
# -m 0: no root-reserved blocks, so Frigate can use the whole image.
mkfs.ext4 -q -m 0 -L frigate "$IMG"

mkdir -p "$MNT"
# nofail: a missing external disk must not stop the server from booting.
# Frigate's init.sh refuses to start while this isn't mounted.
LINE="$IMG $MNT ext4 loop,nofail,x-systemd.requires-mounts-for=/media/external 0 2"
grep -qF "$IMG" /etc/fstab || echo "$LINE" >> /etc/fstab
systemctl daemon-reload
mount "$MNT"

df -h "$MNT"
