# Mosquitto
Official website: [https://mosquitto.org/](https://mosquitto.org/)

An MQTT broker. Frigate publishes its detections and camera state to it, and
Home Assistant's MQTT integration subscribes. It is only reachable inside the
`frontend` network, at `mosquitto:1883`, and requires a login. Each client has
its own account (`frigate`, `homeassistant`), so one can be changed or revoked
without touching the others.

## Setup

1. `cp .env.sample .env` and set a password for each account
   (`openssl rand -hex 24`). To add a client, add a
   `MQTT_USER_<name>=<password>` line; to revoke one, remove its line.
2. `./init.sh`. It rebuilds the hashed password file `./config/passwd` from
   `.env` and restarts the broker. Re-run it whenever you change `.env`.
3. In Home Assistant, go to *Settings > Devices & services > Add integration >
   MQTT* and enter broker `mosquitto`, port `1883`, user `homeassistant` and
   its password from `.env`.

There is nothing to back up beyond `.env`: `./data` only holds retained
messages, which Frigate republishes on start.
