# Authentik
Github: [https://github.com/goauthentik/authentik](https://github.com/goauthentik/authentik)

OIDC / SSO identity provider for the other services in this repo.

## First-time setup

1. Copy `.env.sample` to `.env` and fill in the secrets:
   ```bash
   cp .env.sample .env
   # Generate strong values:
   openssl rand -base64 36   # PG_PASS
   openssl rand -base64 60   # AUTHENTIK_SECRET_KEY
   openssl rand -base64 32   # AUTHENTIK_BOOTSTRAP_TOKEN
   ```
2. Add the `auth.${DOMAIN}` route in `../caddy/Caddyfile` (already done if you followed the SSO setup).
3. Bring it up:
   ```bash
   ./init.sh
   ```
4. Wait ~30s for migrations, then visit `https://auth.${DOMAIN}`.
   Log in as `akadmin` with `AUTHENTIK_BOOTSTRAP_PASSWORD`. Change the password from
   *Directory > Users > akadmin*.

## Upgrading

`AUTHENTIK_TAG` is pinned to an exact patch release, and watchtower is disabled
for the server and worker. Don't use a floating tag like `2025.2`: upstream once
pointed it (and `2025.2.4`) at an arm64-only image, which crash-looped this
x86_64 host with `exec format error`.

Upgrades can't skip versions. Step through the latest patch of every
`major.minor` release in order (see the tag list on ghcr.io), read each
release's notes, and back up the database first:

```bash
docker exec authentik-db pg_dump -U authentik authentik | gzip > ~/backups/authentik-$(date +%F).sql.gz
AUTHENTIK_TAG=<next-version> docker compose up -d server worker   # wait for healthy, repeat
```

Then set the final version in `.env` and in the compose default.

## Adding a service (Nextcloud example)

In Authentik admin:

1. **Applications > Providers > Create > OAuth2/OpenID Provider**
   - Name: `nextcloud`
   - Authorization flow: `default-provider-authorization-explicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://drive.${DOMAIN}/apps/user_oidc/code`
   - Signing Key: `authentik Self-signed Certificate`
   - Save — note the generated **Client ID** and **Client Secret**.
2. **Applications > Applications > Create**
   - Name: `Nextcloud`
   - Slug: `nextcloud`
   - Provider: the one you just made
3. The OIDC discovery URL will be:
   `https://auth.${DOMAIN}/application/o/nextcloud/.well-known/openid-configuration`
