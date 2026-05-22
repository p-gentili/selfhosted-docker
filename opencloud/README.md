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

Both the Web SPA and the iOS app authenticate against the same single
Authentik OAuth2 provider. Configured purely through environment variables —
no `occ`-style post-start CLI commands.

### Prerequisites
- Authentik is running at `https://auth.YOURDOMAIN`
- One OAuth2/OpenID provider + application exists in Authentik:
  - **Client ID: `OpenCloudIOS`** — the iOS SDK hardcodes this as the
    fallback when Dynamic Client Registration is disabled. The Web SPA
    reuses the same Client ID so a single provider serves both clients.
    Authentik treats the value as an opaque string.
  - **Client type: Public** — both clients authenticate with PKCE only.
    A confidential client fails token exchange with `invalid_client`.
  - **Authorization flow: implicit consent** —
    `default-provider-authorization-implicit-consent`. Explicit consent
    breaks silent token renewal in hidden iframes.
  - **Issuer mode: Each provider has different issuer** (per-provider).
    Required so `iss` matches the per-application discovery URL — that's
    the only URL on Authentik that actually serves `.well-known/openid-configuration`.
    "Same as global issuer" mode would set `iss` to the Authentik root,
    where Authentik intentionally 404s discovery and breaks OCIS server-side
    JWKS auto-discovery.
  - **Dynamic Client Registration: disabled** (default). Required so the
    iOS SDK falls back to the static `OpenCloudIOS` client_id rather than
    self-registering with a new dynamic ID under the parent provider.
  - **Redirect URIs** (strict mode):
    - `https://opencloud.YOURDOMAIN/oidc-callback.html`
    - `https://opencloud.YOURDOMAIN/oidc-silent-redirect.html`
    - `https://opencloud.YOURDOMAIN/`
    - `oc://ios.opencloud.eu`
- Copy the **Client ID** (`OpenCloudIOS`) into `.env` as `OIDC_CLIENT_ID`. No
  client secret is needed (or used).

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
