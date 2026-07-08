# SilverBullet
Github: [https://github.com/silverbulletmd/silverbullet](https://github.com/silverbulletmd/silverbullet)

Served at `notes.${DOMAIN}`. Notes live in the bind-mounted `./data` (mounted at `/space`).

## Authentication (Authentik forward auth)

SilverBullet has no OIDC/OAuth support — its only built-in auth is HTTP basic auth
via `SB_USER`. Instead, access is gated in front of it by Authentik using a
**Proxy Provider** and Caddy `forward_auth` (see the `notes.${DOMAIN}` block in
`../caddy/Caddyfile`).

One-time setup in the Authentik admin UI (`https://auth.${DOMAIN}`):

1. **Applications > Providers > Create > Proxy Provider**
   - Name: `silverbullet`
   - Authorization flow: `default-provider-authorization-explicit-consent`
   - Type: **Forward auth (single application)**
   - External host: `https://notes.${DOMAIN}`
   - Save.
2. **Applications > Applications > Create**
   - Name: `SilverBullet`
   - Slug: `silverbullet`
   - Provider: the one you just made.
3. **Applications > Outposts** — edit the built-in **authentik Embedded Outpost**
   and add the `SilverBullet` application to it. (The embedded outpost runs inside
   `authentik-server`, which is what Caddy forwards auth requests to.)

After this, visiting `https://notes.${DOMAIN}` redirects to Authentik for login.
