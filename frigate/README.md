# Frigate
Official website: [https://frigate.video/](https://frigate.video/)

Github: [https://github.com/blakeblackshear/frigate](https://github.com/blakeblackshear/frigate)

An NVR for the Tapo C210. It records the 2K stream, spots people on the
640x360 substream using the Intel GPU, and sends what it sees to Home
Assistant over MQTT ([`../mosquitto`](../mosquitto)). The web UI is at
`frigate.DOMAIN`, behind Frigate's own login.

## Recordings

Recordings, clips and snapshots go to `/media/external/frigate`, outside
`/srv`. They are kept by age (`record:` in `config.yml`): everything for 3
days, motion for 7, and alerts and detections for 30. At 2K the C210 records
roughly 20 GB a day continuously (an estimate; check *System > Storage* in
the UI after a few days). If the external drive ever runs nearly full,
Frigate deletes its oldest recordings first.

## Setup

1. **Camera account.** In the Tapo app, go to the camera's *Settings >
   Advanced Settings > Camera Account* and create a user. Frigate uses it for
   the video and for pan/tilt. Give the camera a fixed IP address in the
   router.
2. **MQTT.** Set up [`../mosquitto`](../mosquitto) first.
3. **Config.** `cp .env.sample .env` and fill in the camera's IP and account,
   and the password of the `frigate` account from `../mosquitto/.env`.
4. **DNS.** Add a record for `frigate.DOMAIN` (already in
   `../caddy/Caddyfile`), then restart Caddy.
5. `./init.sh`. On the first run it copies `config.template.yml` to
   `./config/config.yml`. From then on, that file is the one to edit, or use
   the UI, which edits it in place.
6. Get the admin password from the logs:
   `docker logs frigate 2>&1 | grep -A2 Password`. Then open
   `https://frigate.DOMAIN`, log in as `admin`, and change it under
   *Settings > Users*.

## Pan/tilt

The C210's ONVIF service on port 2020 gives the live view arrow controls,
using the same camera account. Autotracking (following a person) needs
ONVIF relative moves, which Tapo cameras don't usually offer, so expect it
not to work. The Tapo app keeps working alongside Frigate.

## Home Assistant

Frigate's integration is not built into Home Assistant, and the server has no
HACS, so `install-ha-integration.sh` installs it from its GitHub release.

1. In Home Assistant, add the **MQTT** integration (see
   [`../mosquitto`](../mosquitto)).
2. `./install-ha-integration.sh`, then `docker restart homeassistant`.
3. In Home Assistant, go to *Settings > Devices & services > Add integration
   > Frigate*:
   - URL: `http://frigate:8971`
   - Username and password: a Frigate user. Create a separate one for Home
     Assistant under *Settings > Users* in Frigate.

This adds a camera entity for the C210, person-detected sensors, switches
for recording and detection, and the recordings in Home Assistant's media
browser. To upgrade the integration, re-run the script with a newer tag
(`./install-ha-integration.sh v5.16.0`) and restart Home Assistant.

## Backup

`pre-backup.sh` stops Frigate and `post-backup.sh` starts it again, because
`./config` holds a live SQLite database. The recordings live on the external
drive, outside `/srv`, so they are not part of the backup.
