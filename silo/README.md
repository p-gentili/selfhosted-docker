# Silo
Official website: [https://siloserver.org/](https://siloserver.org/)

Github: [https://github.com/Silo-Server/silo-server](https://github.com/Silo-Server/silo-server)

A media server that runs **alongside Jellyfin on the same library**.
`/media/external/media` is mounted read-only at `/mnt/media`, so Silo can
scan it and fetch metadata but never write into it. Jellyfin keeps its own
read-write mount and its own database. The two servers share no state, so each
keeps its own watch history.

The image is Silo's single-container "omnibus" build. It bundles PostgreSQL
(with pgvector) and Redis, and stores everything under `./config`.

## Setup

1. Copy `.env.sample` to `.env`:
   ```bash
   cp .env.sample .env
   openssl rand -base64 48   # SECRET_KEY
   ```
   Set `PUID`/`PGID` to an account that can read `/media/external/media`
   (`ls -ln /media/external/media`). **Store `SECRET_KEY` somewhere outside
   this directory's backups.** If it is lost, every secret Silo has encrypted
   (including the Authentik client secret) is unrecoverable.
2. Add a DNS record for `silo.DOMAIN` (already in `../caddy/Caddyfile`), then
   reload Caddy.
3. `./init.sh`
4. Open `https://silo.DOMAIN` and finish first-run setup. The account it
   creates is the **Owner**, which is a break-glass local login. Keep its
   password: it is how you get in if Authentik is down.
5. Go to **Admin > Server > General** and set **Silo public URL** to
   `https://silo.DOMAIN`. Restart if Silo asks you to. OIDC callback URLs are
   built from this setting, so they stay empty until it is set.
6. Add a library pointing at a folder under `/mnt/media`, such as
   `/mnt/media/Movies`. These are the same folders as Jellyfin's `/media/...`.

Hardware transcoding uses the same `/dev/dri/renderD128` node as Jellyfin.
On start, the image adds its `PUID` user to the device's group.

## Sign-in with Authentik

Silo gets OIDC from its first-party **OpenID Connect** plugin
([silo-plugin-auth-oidc](https://github.com/Silo-Server/silo-plugin-auth-oidc)).
The plugin is installed from the admin UI, not from this compose file.

1. **In Silo:** install the *OpenID Connect* sign-in plugin from the plugin
   catalog and open its settings. The Sign-in settings page shows the
   **callback URL** to register at the provider. It has the form
   `https://silo.DOMAIN/api/v2/auth/oauth/<installation id>/callback`.
2. **In Authentik:** go to *Applications > Providers > Create > OAuth2/OpenID
   Provider*:
   - Name: `silo`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: the callback URL from step 1 (strict)
   - Signing Key: `authentik Self-signed Certificate`. **This is required.**
     Without one, Authentik signs with HS256, which the plugin refuses.
   - Advanced protocol settings > Scopes: add
     `authentik default OAuth Mapping: OpenID 'offline_access'` next to the
     defaults.
   - Note the **Client ID** and **Client Secret**.

   Then go to *Applications > Applications > Create*, with Name `Silo`, Slug
   `silo`, and Provider `silo`.
3. **Back in Silo**, under the plugin's *Provider connection*:
   - Issuer URL: `https://auth.DOMAIN/application/o/silo/`. **The trailing
     slash is required.** The plugin checks that it matches the discovery
     document exactly.
   - Client ID / Client secret: from step 2.
   - Request offline access: on. Refresh token lifetime: `30d`, which is
     Authentik's default *Refresh Token validity*. Change it here if you
     change it there. With offline access on, Silo re-checks accounts at
     Authentik, so a user you disable there is signed out of Silo as well.
   - Button label: `authentik`.
   - Run the connection test.
4. *Optional:* under *Access rules*, set *Allowed groups* or *Admin groups*.
   Authentik sends `groups` with the `profile` scope, so no extra scope is
   needed.

New Authentik users get a Silo account automatically on their first sign-in.
To link the existing **Owner** account instead, sign in locally and use
*Connect authentik* in your account settings. Email auto-match is off by
default and never applies to admins. Authentik always reports
`email_verified=false`, so auto-match would not apply anyway.

Leave the plugin's `prompt` setting at the provider default. Since 2026.8,
Authentik has made the OpenCloud iOS app enter the password twice under
`prompt=login`, so avoid sending it here too.

## Backup

`pre-backup.sh` stops the container and `post-backup.sh` starts it again.
`./config` holds a live PostgreSQL cluster, which a file copy only captures
consistently while it is stopped. `./transcode` and `./download-artifacts`
are disposable.
