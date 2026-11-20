# Home Assistant
Official website: [https://www.home-assistant.io/](https://www.home-assistant.io/)

Github: [https://github.com/home-assistant/core](https://github.com/home-assistant/core)

The container runs on the `frontend` network and Caddy serves it at
`assistant.DOMAIN` (already in `../caddy/Caddyfile`). It runs `privileged`
with `/run/dbus` mounted so that Home Assistant can reach the host's Bluetooth
adapter.

Because it is not on the host network, Home Assistant cannot auto-discover
devices that rely on mDNS/SSDP broadcasts. Add those integrations by IP
instead.

## Setup

1. `./init.sh`. On the first start, Home Assistant creates `./config`.
2. Tell Home Assistant to trust Caddy as a reverse proxy. If you skip this
   step, every request through `assistant.DOMAIN` gets `400 Bad Request`. Add
   the following to `./config/configuration.yaml`:
   ```yaml
   http:
     use_x_forwarded_for: true
     trusted_proxies:
       - 172.18.0.24   # caddy's fixed address on the frontend network
   ```
   Then run `docker restart homeassistant`. See
   [HTTP - Reverse Proxies](https://www.home-assistant.io/integrations/http/#reverse-proxies).
3. Add a DNS record for `assistant.DOMAIN`, then open it and finish
   onboarding.

## Backup

`pre-backup.sh` stops the container and `post-backup.sh` starts it again.
`./config` holds the recorder's live SQLite database, which a file copy only
captures consistently while the container is stopped.
