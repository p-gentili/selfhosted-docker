# Mosquitto
Official website: [https://mosquitto.org/](https://mosquitto.org/)

An MQTT broker. Frigate publishes its detections and camera state to it, and
Home Assistant's MQTT integration subscribes. It is only reachable inside the
`frontend` network, at `mosquitto:1883`, and requires a login.

## Setup

1. `cp .env.sample .env` and set `MQTT_PASSWORD` (`openssl rand -hex 24`).
2. `./init.sh`. It writes the hashed password file to `./config/passwd` and
   starts the broker. Re-run it whenever you change `.env`.
3. In Home Assistant, go to *Settings > Devices & services > Add integration >
   MQTT* and enter broker `mosquitto`, port `1883`, and the user and password
   from `.env`.

There is nothing to back up beyond `.env`: `./data` only holds retained
messages, which Frigate republishes on start.
