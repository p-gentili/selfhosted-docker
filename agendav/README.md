# AgenDAV

Official website: [https://agendav.org](https://agendav.org)

Github: [https://github.com/agendav/agendav](https://github.com/agendav/agendav)

A CalDAV web client, giving the calendars served by the OpenCloud stack's
Radicale a browser UI. OpenCloud itself has none.

**Calendars only.** AgenDAV does not speak CardDAV, so the `def-addressbook`
collection stays client-only — this adds no contacts UI.

## How it fits together

```
browser ──> Caddy (calendar.DOMAIN) ──> agendav:80
agendav ──> http://opencloud:9200/caldav/ ──> [proxy authenticates] ──> radicale:5232
```

AgenDAV holds no accounts of its own. You log in with an **OpenCloud username
and an app token**, and it replays those as HTTP Basic credentials on every
CalDAV request. OpenCloud's proxy is the authentication boundary exactly as it
is for any other CalDAV client, so this stack changes nothing in `opencloud/`.

The container joins only `frontend`, where it reaches `opencloud` by container
name. It deliberately does **not** join the opencloud stack's `backend`
network: Radicale trusts `X-Remote-User` unconditionally and must stay
reachable only through the proxy.

### Why it finds the right calendars

Radicale keys collections by OpenCloud's **opaque user ID** — a UUID — not the
username, so a URL assembled from a username gets a 403 (see
`opencloud/README.md`). AgenDAV never assembles one. At login it PROPFINDs
`DAV:current-user-principal` against `caldav.baseurl`, then follows
`calendar-home-set` from the principal it gets back.

This works through a path prefix because `opencloud/proxy.yaml` sets
`X-Script-Name: /caldav`, so the hrefs Radicale returns are absolute paths that
resolve correctly against the base URL.

AgenDAV does support a `%u` username placeholder in `caldav.baseurl`. **Do not
use it here** — it is the one thing guaranteed to break against this backend.

## Setup

1. `cp .env.sample .env` and fill it in. Generate both secrets:

   ```bash
   openssl rand -hex 32   # once for AGENDAV_CSRF_SECRET
   openssl rand -hex 32   # again for AGENDAV_SESSION_KEY
   ```

   `init.sh` refuses to start while either is still `changeme`.

2. Add a DNS record for `calendar.DOMAIN` pointing at the host, as for every
   other stack.

3. `./init.sh`

4. Create an app token for yourself, if you do not already have one:

   ```bash
   docker exec opencloud opencloud auth-app create \
       --user-name=USERNAME --expiration=8760h
   ```

   Log in at `https://calendar.DOMAIN` with your OpenCloud username and that
   token as the password. Tokens are individually revocable, so use one
   dedicated to AgenDAV rather than reusing a client's.

## Checking it before blaming the UI

AgenDAV's login refuses to proceed unless an `OPTIONS` request returns 2xx
**and** a `DAV` response header. That single requirement is the usual cause of
a login that fails with correct credentials:

```bash
curl -sSi -X OPTIONS -u 'USERNAME:APP_TOKEN' https://opencloud.DOMAIN/caldav/ | head -20
```

No `DAV:` header in the response means AgenDAV cannot log in, and nothing in
this stack's config will change that — the problem is on the proxy side.

Then confirm discovery returns a principal:

```bash
curl -sS -X PROPFIND -u 'USERNAME:APP_TOKEN' -H 'Depth: 0' \
    --data '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>' \
    https://opencloud.DOMAIN/caldav/
```

The href it returns is the UUID path AgenDAV will use.

## No published image

AgenDAV publishes no container image to any registry. `init.sh` therefore
shallow-clones a pinned tag into `./src` (gitignored) and `docker-compose.yml`
builds [upstream's own production
Dockerfile](https://github.com/agendav/agendav/blob/main/Dockerfile) from it,
which costs a few minutes of composer and npm work on first run.

### Why a clone rather than a git build context

Docker can build straight from `https://github.com/agendav/agendav.git#3.3.1`,
which would be tidier — but upstream's production Dockerfile **cannot build
from a clean checkout**. It ends with:

```dockerfile
RUN chmod -R 750 /app/var /app/config
```

`var/` holds only generated files, and the `var/.gitkeep` that kept it in the
repo was deleted in
[ae1c3504](https://github.com/agendav/agendav/commit/ae1c3504) — a commit
titled *"fix(docker): Ensure write access to var dir"*, which added
`mkdir -p /app/var` to the **development** Dockerfile and missed the
production one. Upstream CI only runs composer and npm, so the break shipped in
3.3.0 and is still present on `main`:

```
chmod: cannot access '/app/var': No such file or directory
```

Cloning lets `init.sh` recreate that one directory before building, so
upstream's Dockerfile is used **unmodified**. The alternative — inlining a
patched copy of their Dockerfile — would mean silently tracking their build
steps forever. Recreating the directory is the whole fix; if upstream repairs
it, the `mkdir` simply becomes a no-op.

Two further consequences:

- **Watchtower will not update this container.** It only updates images pulled
  from a registry. That is deliberate rather than unfortunate: upstream
  describes itself as in maintenance mode, so updates should be a decision.
- **Upgrading** means bumping `AGENDAV_VERSION` in `init.sh` and re-running it,
  which re-checks out, rebuilds and re-applies migrations.

The unofficial `ghcr.io/nagimov/agendav-docker` image was considered and
rejected: it pins AgenDAV 2.6.0, was last built in June 2025 on a
now-EOL Debian base, is stateless (losing your session on every restart), and
stores the CalDAV password in the session unencrypted. Since that password is a
long-lived OpenCloud app token here, the last point matters.

## Configuration

`settings.php` is generated from `settings.template.php` by `init.sh`, the same
way `opencloud/init.sh` renders `csp.yaml`. It is gitignored because it carries
both secrets. Edit the template, then re-run `init.sh`.

`session.encryption.key` is what encrypts the app token held in each session.
Changing it invalidates existing sessions, which only means logging in again.

## Backup

`pre-backup.sh` stops the container and `post-backup.sh` starts it again, so
the SQLite store under `./data` is snapshotted consistently — it is written in
place with no transactional guarantees.

The database holds sessions, user preferences and subscriptions only. Every
calendar and event lives in Radicale, and is covered by the opencloud stack's
own backup.
