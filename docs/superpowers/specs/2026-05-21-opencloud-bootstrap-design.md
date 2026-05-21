# OpenCloud bootstrap (parallel with Nextcloud)

## Goal

Stand up an OpenCloud stack alongside the existing Nextcloud stack so they can run
in parallel during a migration period. OpenCloud is expected to replace Nextcloud
eventually; this design intentionally avoids any coupling between the two stacks so
Nextcloud can be removed cleanly later.

## Architecture

A new top-level `opencloud/` directory mirroring the per-service convention used by
every other app in this repo (`docker-compose.yml`, `init.sh`, `.env.sample`,
`pre-backup.sh`, `post-backup.sh`, `README.md`, `.gitignore`).

Three containers in the stack:

- **opencloud** — the OCIS-based main service (image: `opencloudeu/opencloud:latest`).
  Listens on `:9200`. Joined to the external `frontend` network so Caddy can
  reach it, and to an internal `backend` network for WOPI traffic.
- **opencloud-collaboration** — WOPI bridge built into the OpenCloud binary
  (same image, run with `opencloud collaboration server`). Listens on `:9300`.
  Exposed externally at `collaboration.{$DOMAIN}` because the user's browser
  talks to it directly during office editing.
- **collabora** — dedicated Collabora CODE instance for OpenCloud (image:
  `collabora/code:latest`). Separate from the Nextcloud Collabora so the two
  stacks remain independent. Exposed externally at `collabora.{$DOMAIN}`.

No database container — OCIS uses embedded storage (boltdb + filesystem) rather
than MariaDB. This means backup is just "stop container, snapshot data dir,
start container" — no DB dump step.

### Networks

- `frontend` (external, already created by `caddy/init.sh`): shared with Caddy.
  `opencloud`, `opencloud-collaboration`, and `collabora` all join it (all three
  need to be reachable by Caddy).
- `backend` (internal to this stack): connects `opencloud`,
  `opencloud-collaboration`, and `collabora` for the WOPI flow.

### Volumes

Bind mounts under the repo, matching Nextcloud's pattern:

- `./opencloud/data` — OpenCloud user file storage.
- `./opencloud/config` — OpenCloud config (signing keys, JWT secret, etc.).

Both go in `.gitignore`.

## Reverse proxy (Caddy)

Three new entries appended to `caddy/Caddyfile`, leaving the existing `drive.`
and `office.` (Nextcloud + its Collabora) blocks untouched:

```caddy
opencloud.{$DOMAIN} {
    reverse_proxy opencloud:9200 {
        transport http { tls_insecure_skip_verify }
        header_up X-Real-IP {remote_host}
    }
}

collaboration.{$DOMAIN} {
    reverse_proxy opencloud-collaboration:9300 {
        header_up X-Real-IP {remote_host}
    }
}

collabora.{$DOMAIN} {
    reverse_proxy opencloud-collabora:9980 {
        transport http { tls_insecure_skip_verify }
    }
}
```

`tls_insecure_skip_verify` is required because both OpenCloud and Collabora
present self-signed certs internally; TLS to the public internet is terminated
by Caddy.

## Auth (OIDC via Authentik)

OpenCloud is configured for external OIDC purely through environment variables on
the `opencloud` container — no post-start CLI commands (unlike Nextcloud's `occ
user_oidc:provider`). Key env vars:

- `OC_URL=https://opencloud.{$DOMAIN}`
- `OC_OIDC_ISSUER=https://auth.{$DOMAIN}/application/o/opencloud/`
- `WEB_OIDC_CLIENT_ID=opencloud`
- `PROXY_AUTOPROVISION_ACCOUNTS=true` — create OpenCloud users on first SSO login
- `PROXY_ROLE_ASSIGNMENT_DRIVER=oidc` (optional, for role mapping later)
- `PROXY_OIDC_REWRITE_WELLKNOWN=true` — Authentik's discovery doc differs slightly
  from the spec OCIS expects; rewriting it fixes that

The README documents the one-time Authentik side: create an OAuth2/OpenID
provider + application named `opencloud` with redirect URI
`https://opencloud.{$DOMAIN}/oidc-callback`. Client ID/secret get pasted into
`.env`.

## Environment variables (`.env.sample`)

```
OPENCLOUD_FQDN="https://opencloud.example.com"
COLLABORA_FQDN="https://collabora.example.com"
INITIAL_ADMIN_PASSWORD="changeme"
COLLABORA_PASSWORD="changeme"
OIDC_CLIENT_ID="opencloud"
OIDC_CLIENT_SECRET=""
PROXY_IP="192.168.1.1"
```

## Scripts

- `init.sh` — same shape as `nextcloud/init.sh`: source `.env`, `docker compose
  down -v`, `up -d`. No DB restore step (no DB).
- `pre-backup.sh` — `docker compose stop opencloud` so the data dir is
  consistent. (OCIS writes through to disk continuously; stopping is the simplest
  way to get a clean snapshot.)
- `post-backup.sh` — `docker compose start opencloud`.

## Files touched

New:

- `opencloud/docker-compose.yml`
- `opencloud/.env.sample`
- `opencloud/.gitignore` — ignore `.env`, `data/`, `config/`
- `opencloud/init.sh`
- `opencloud/pre-backup.sh`
- `opencloud/post-backup.sh`
- `opencloud/README.md`

Modified:

- `caddy/Caddyfile` — add `opencloud.`, `collaboration.`, and `collabora.` blocks
- `README.md` — add `opencloud` subgraph to the mermaid diagram

## Out of scope (deliberately deferred)

- Data migration from Nextcloud to OpenCloud (separate effort once OpenCloud
  proves itself).
- Tearing down the Nextcloud stack — explicitly kept running in parallel.
- Tika (full-text search for OpenCloud) — can be added later.
- Role/group mapping from Authentik claims — initial setup uses
  autoprovisioning with the default user role.
