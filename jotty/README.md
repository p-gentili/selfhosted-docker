# Jotty
Official website: [https://jotty.page/](https://jotty.page/)

Github: [https://github.com/fccview/jotty](https://github.com/fccview/jotty)

Notes and checklists stored as plain files under `./data`, served at
`notes.DOMAIN`. No database. Watchtower keeps `latest` current.

## Setup

1. `cp .env.sample .env` and set `DOMAIN` (e.g. `home.pgentili.com`).
   Leave the OIDC values empty for now if Authentik is not set up yet, and
   comment out `AUTH_MODE` so the first run uses local login.
2. Add a DNS record for `notes.DOMAIN` (already in `../caddy/Caddyfile`), then
   **restart** Caddy (a reload can serve a stale bind-mounted Caddyfile).
3. `sudo ./init.sh` (it chowns the data folders, so it needs root).
4. Open `https://notes.DOMAIN`. The first visit goes to `/auth/setup`: the
   account created there is the System Owner. Keep its password as a
   break-glass login.

## Sign-in with Authentik

1. **In Authentik:** *Applications > Providers > Create > OAuth2/OpenID
   Provider*:
   - Name: `jotty`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://notes.DOMAIN/api/oidc/callback` (strict)
   - Signing Key: `authentik Self-signed Certificate`
   - Note the **Client ID** and **Client Secret**.

   Then *Applications > Applications > Create*: Name `Jotty`, Slug `jotty`,
   Provider `jotty`, Launch URL `https://notes.DOMAIN`.
2. **In `.env`:** set `AUTH_MODE=oidc`, `OIDC_ISSUER`
   (`https://auth.DOMAIN/application/o/jotty/`, trailing slash),
   `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET`, then `sudo ./init.sh`.
3. The login page now shows an SSO button next to the local form
   (`SSO_FALLBACK_LOCAL=yes`). Members of `OIDC_ADMIN_GROUPS` get admin.

Jotty uses PKCE (S256) with the authorization code flow, which Authentik
supports with no extra settings. Groups come with Authentik's `profile`
scope, so `OIDC_GROUPS_SCOPE=no` stops Jotty asking for a `groups` scope
Authentik does not have.

## Backup

`pre-backup.sh` stops the container and `post-backup.sh` starts it again.
`./data` and `./config` hold everything; `./cache` is disposable.
