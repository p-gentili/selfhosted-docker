# OpenCloud
Official website: [https://opencloud.eu](https://opencloud.eu)

Github: [https://github.com/opencloud-eu/opencloud](https://github.com/opencloud-eu/opencloud)

OpenCloud is the OCIS-based successor to ownCloud. This stack runs in parallel
with the existing Nextcloud deployment during migration; both are independent and
share no containers, volumes, or databases.

## Collabora CODE
Official website: [https://www.collaboraonline.com/code/](https://www.collaboraonline.com/code/)

This stack ships its own dedicated Collabora instance (separate from the one in
the Nextcloud stack). Office editing flows through OpenCloud's built-in
collaboration service (the WOPI bridge), which is a second container running the
same `opencloud` image with a different command.

## OIDC SSO via Authentik

OpenCloud is configured for external OIDC purely through environment variables —
no `occ`-style post-start CLI commands.

### Prerequisites
- Authentik is running at `https://auth.YOURDOMAIN`
- An OAuth2/OpenID **provider** and **application** named `opencloud` exist in
  Authentik (slug = `opencloud`, redirect URI = `https://opencloud.YOURDOMAIN/oidc-callback`)
- You have copied the **Client ID** and **Client Secret** from the provider into
  `.env` as `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET`

### How it works
With `PROXY_AUTOPROVISION_ACCOUNTS=true`, the first time an Authentik user logs
in OpenCloud creates a local user record automatically. The `preferred_username`
claim is used as the OpenCloud username, matching the convention used in the
Nextcloud stack — so as long as Authentik usernames are stable, this is the
identifier that will tie back to a user's data over time.

### Recovering the initial admin
The `INITIAL_ADMIN_PASSWORD` env var only takes effect the very first time the
stack comes up (when `opencloud init` runs). After that, change it through the
web UI or with `docker exec opencloud opencloud idm`.

## Backup considerations

Unlike Nextcloud (MariaDB + filesystem), OpenCloud uses embedded storage
(boltdb + files under `./data`). `pre-backup.sh` stops just the `opencloud`
container so the data directory is consistent for snapshotting;
`post-backup.sh` starts it again. Collabora and the collaboration service stay
running — they are stateless.

## Parallel-with-Nextcloud notes

- OpenCloud lives on `opencloud.YOURDOMAIN`; Nextcloud stays on
  `drive.YOURDOMAIN`. No conflicts.
- Each stack has its own Collabora; the two never share a WOPI host.
- When Nextcloud is eventually retired, this stack stands on its own — nothing
  in `opencloud/` references the Nextcloud stack.
