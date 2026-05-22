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

## Authentication

The Web SPA uses **OIDC SSO via Authentik**. The iOS app uses **basic auth +
app passwords** against OpenCloud's local IDM. The two clients use different
auth paths intentionally — see "Why iOS doesn't use OIDC" below.

### OIDC SSO via Authentik (Web only)

Configured purely through environment variables — no `occ`-style post-start
CLI commands.

#### Prerequisites
- Authentik is running at `https://auth.YOURDOMAIN`
- One OAuth2/OpenID provider + application named `opencloud` exists in
  Authentik:
  - **Client type: Public** — the Web SPA authenticates with PKCE only.
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
  - **Redirect URIs** (strict mode):
    - `https://opencloud.YOURDOMAIN/oidc-callback.html`
    - `https://opencloud.YOURDOMAIN/oidc-silent-redirect.html`
    - `https://opencloud.YOURDOMAIN/`
- Copy the **Client ID** into `.env` as `OIDC_CLIENT_ID`. No client secret is
  needed (or used).

#### How it works
With `PROXY_AUTOPROVISION_ACCOUNTS=true`, the first time an Authentik user logs
in OpenCloud creates a local user record automatically. The `preferred_username`
claim is used as the OpenCloud username, matching the convention used in the
Nextcloud stack — so as long as Authentik usernames are stable, this is the
identifier that will tie back to a user's data over time.

### iOS app: basic auth + app passwords

`PROXY_ENABLE_BASIC_AUTH=true` is set so the iOS app can authenticate via
HTTP basic auth against OpenCloud's local IDM. Onboarding flow per user:

1. User signs in to the Web UI once via OIDC — this auto-provisions the local
   account.
2. From the Web UI, the user creates an **app password** for their iOS device.
3. In the iOS app, the user adds the OpenCloud server and authenticates with
   their username + that app password.

#### Why iOS doesn't use OIDC

Sharing a single Authentik OIDC provider between the Web SPA and the iOS app
isn't practical:

- The two clients need different redirect URIs (`https://opencloud.../...` vs
  `oc://ios.opencloud.eu`), so they can't share strict-mode URI lists *and*
  the same `client_id` — the iOS app's `client_id` defaults to `OpenCloudIOS`
  (hardcoded in the SDK, overridable only at build time or via MDM).
- Using two separate Authentik providers requires both to emit the same `iss`
  so OCIS can validate tokens from either, which means "Same as global issuer"
  mode. But that mode disables Authentik's per-app discovery semantics at the
  root URL (404), and OCIS depends on discovery for both JWKS and userinfo
  endpoint lookup. Neither `PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD=none` nor
  the various OCIS proxy knobs let server-side validation bypass discovery
  entirely — confirmed by the OCIS proxy source. The Authentik maintainers'
  explicit position: "Same as global" is only for clients that validate `iss`
  as a string without performing discovery.
- The remaining workaround — proxying the Authentik root's `.well-known` to a
  per-app endpoint via Caddy — couples a shared-identity service to one
  downstream stack's config, which we don't want.

Basic auth + app passwords is the standard ownCloud/OpenCloud iOS pattern and
sidesteps the entire problem; the iOS device never needs to talk to Authentik.

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
