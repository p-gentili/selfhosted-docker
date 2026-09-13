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

### Debugging a 500

The container runs with `AGENDAV_ENVIRONMENT=prod`, which deliberately
suppresses stack traces — so a fault shows up as a blank 500 with nothing in
`docker logs` beyond the Apache access line. To see the actual exception, run
the image once with the environment flipped:

```bash
docker run --rm -p 18080:80 -e AGENDAV_ENVIRONMENT=dev \
    -v "$PWD/settings.php:/app/config/settings.php:ro" \
    -v "$PWD/data:/app/database" -v "$PWD/var:/app/var" \
    agendav-agendav:latest
```

The trace is then rendered in the response body. Never leave the deployed
stack in `dev`.

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

Cloning lets `init.sh` recreate that one directory before building. The
alternative — inlining a patched copy of their Dockerfile — would mean
silently tracking their build steps forever. If upstream repairs it, the
`mkdir` simply becomes a no-op.

### Missing icon fonts — a second bug in the same Dockerfile

`package.json` defines the asset build as four steps:

```
build:assets = build:templates && build:copy && build:css && build:js
```

The production Dockerfile runs only three, **skipping `build:copy`**. That is
the step which copies Font Awesome and Bootstrap glyphicon fonts out of
`node_modules`, along with the fullcalendar locales and jquery-ui theme
images. All of those paths are gitignored, so they exist nowhere else in a
checkout, and the compiled CSS then asks for files that were never created:

```
url('../../font/fa/fontawesome-webfont.woff2?v=4.2.0')
url("../../font/bootstrap/glyphicons-halflings-regular.woff2")
```

The build succeeds, so nothing looks wrong — but those 404, and **every icon
in the UI renders broken**. The fullcalendar locales are missing too, so any
non-English locale would fail as well.

`init.sh` inserts the missing step into the cloned Dockerfile before building.
Both repairs are guarded: if upstream changes the line being patched,
`init.sh` **fails loudly** rather than quietly producing broken icons again,
and if upstream fixes it the patch becomes a no-op.

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

### Sessions are files, not database rows

AgenDAV keeps sessions in the database by default, through Symfony's
`PdoSessionHandler`. Upstream wires that handler with `LOCK_ADVISORY`, and
SQLite has no advisory locks, so every request dies at `session_start()` with:

```
DomainException: SQLite does not support advisory locks
```

The lock mode is hardcoded in `app/services.php` (chosen so the session
connection cannot collide with Doctrine's transactions) and cannot be
overridden from configuration, so `settings.template.php` sets
`session.handler = 'native'` to use PHP file sessions instead.

Those session files live inside the container, so recreating it — which
`init.sh` does on every run — logs you out. Expect to re-enter your username
and app token after an upgrade.

### The database must be owned by www-data

`init.sh` runs the migrations with `--user www-data`. The image declares no
default user, so a plain `docker compose exec` runs them as **root**, creating
`agendav.sqlite` root-owned; Apache's workers can then read the database but
not write it, and every request returns 500. The ownership check in `init.sh`
inspects the *contents* of `data/` rather than just the directory, so a
database left root-owned by an earlier run gets corrected on the next run.

## Backup

`pre-backup.sh` stops the container and `post-backup.sh` starts it again, so
the SQLite store under `./data` is snapshotted consistently — it is written in
place with no transactional guarantees.

The database holds sessions, user preferences and subscriptions only. Every
calendar and event lives in Radicale, and is covered by the opencloud stack's
own backup.
