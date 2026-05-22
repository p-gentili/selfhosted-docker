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
- **Two** OAuth2/OpenID providers + applications exist in Authentik — one per
  client, because the Web SPA and the iOS app have different redirect URI
  schemes that can't share a single provider in strict mode:
  - `opencloud` — for the Web SPA. Redirect URIs (strict mode):
    - `https://opencloud.YOURDOMAIN/oidc-callback.html`
    - `https://opencloud.YOURDOMAIN/oidc-silent-redirect.html`
    - `https://opencloud.YOURDOMAIN/`
  - `opencloud-ios` — for the iOS app. Redirect URI (strict mode):
    - `oc://ios.opencloud.eu`

  Both providers must use:
  - **Client type: Public** — both clients authenticate with PKCE only.
    Confidential clients fail token exchange with `invalid_client`.
  - **Authorization flow: implicit consent** —
    `default-provider-authorization-implicit-consent`. Explicit consent
    breaks silent token renewal in hidden iframes.
  - **Issuer mode: Same as global issuer** — both providers must emit the
    same `iss` claim (`https://auth.YOURDOMAIN/`). OpenCloud's
    `OC_OIDC_ISSUER` validates against this single value, so a user logging
    in via either client lands as the same account.

- Copy the Web provider's **Client ID** into `.env` as `OIDC_CLIENT_ID`. No
  client secret is needed. The iOS Client ID is configured inside the app and
  doesn't appear in this stack's `.env`.

### Why two metadata URLs in .env

`OIDC_ISSUER_URL` is the **global** Authentik URL (`https://auth.YOURDOMAIN/`)
— what OpenCloud validates the JWT `iss` claim against. `OIDC_WEB_METADATA_URL`
is the **per-application** discovery URL that the browser SPA fetches. They
can't be the same: Authentik has no global `/.well-known/openid-configuration`
endpoint (it 404s), and even if it did, a global endpoint has no provider
context and can't emit a CORS `Access-Control-Allow-Origin` header for the
Web origin. The per-app discovery endpoint matches Origin against that
provider's redirect URIs and emits CORS correctly.

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
