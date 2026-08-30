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
  - **Client ID: whatever Authentik generated** — no specific value is
    required. The Web SPA and the iOS app both use it; see "How native
    clients learn their client_id" below for why iOS doesn't need a
    special name.
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
  - **Scopes**: `openid`, `profile`, `email`, and `offline_access` — all four
    are Authentik's built-in mappings. `offline_access` is not attached by
    default and is easy to miss: the Web SPA doesn't ask for it, but the
    native clients do. Without it they log in fine and then get silently
    signed out when the access token expires, because no refresh token is
    ever issued.
  - **Redirect URIs** (strict mode):
    - `https://opencloud.YOURDOMAIN/oidc-callback.html`
    - `https://opencloud.YOURDOMAIN/oidc-silent-redirect.html`
    - `https://opencloud.YOURDOMAIN/`
    - `oc://ios.opencloud.eu` — the iOS app's custom URL scheme. This one
      is compiled into the app and is *not* discoverable, so it has to be
      registered by hand.
- Copy the **Client ID** into `.env` as `OIDC_CLIENT_ID`. No client secret is
  needed (or used).

### How native clients learn their client_id

The Web SPA reads its client_id from `config.json`, but the iOS, Android, and
desktop apps don't: they ask OpenCloud's WebFinger service, at
`/.well-known/webfinger?resource=<server>&platform=ios`. The response carries
`http://opencloud.eu/ns/oidc/client_id` and `.../scopes` properties, and the
app uses whatever it finds there (see upstream ADR 0003).

Out of the box that answers with the literal string `OpenCloudIOS`. Authentik
has no provider by that name, so the app sends an unknown client_id and — after
the user has already typed their password — the login dies with *"The client
identifier (client_id) is missing or invalid"*.

`WEBFINGER_IOS_OIDC_CLIENT_ID` in `docker-compose.yml` overrides that default
with the same client the Web SPA uses, so one Authentik provider serves both.
This is the supported mechanism, and it is the reason the provider's Client ID
can be any value: the server tells the app what to use.

Note this is only necessary because Authentik does not implement OIDC Dynamic
Client Registration — its discovery document has no `registration_endpoint`, so
native apps cannot register themselves and must be pointed at a pre-registered
client. That is the standard pattern for public native clients (RFC 8252): the
client_id is not a secret, and PKCE provides the security.

`WEBFINGER_ANDROID_OIDC_CLIENT_ID` and `WEBFINGER_DESKTOP_OIDC_CLIENT_ID`
default to `OpenCloudAndroid` / `OpenCloudDesktop` and will fail the same way if
those clients are ever used; they need the same treatment.

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

## Calendars and contacts via Radicale

CalDAV and CardDAV are served by a [Radicale](https://radicale.org/) container
(`opencloudeu/radicale`), wired up the way upstream documents in
[Calendar and Contacts Integration with Radicale](https://docs.opencloud.eu/docs/admin/configuration/radicale-integration/).
Requires OpenCloud >= 2.3.0; this stack tracks `latest`.

OpenCloud has no UI for calendars or contacts — this only provides the server.
Use any CalDAV/CardDAV client.

### How it fits together

`proxy.yaml` (copied into `config/` by `init.sh`) adds four routes to the
OpenCloud proxy: `/caldav/`, `/carddav/`, and the two matching `.well-known`
endpoints. The proxy authenticates the request — OIDC session or app token —
resolves the user, and forwards to `radicale:5232` with the username in
`X-Remote-User` and an `X-Script-Name` telling Radicale which prefix it is
mounted under, so the hrefs it returns are paths the client can actually
follow.

Radicale therefore runs with `auth type = http_x_remote_user`: it does no
authentication of its own and trusts that header completely. **That is only
safe because it is unreachable except through the proxy.** The container joins
`backend` and not `frontend`, and Caddy has no route to it. Radicale logs a
warning at startup that `http_x_remote_user` is selected while listening on
`0.0.0.0` rather than loopback — expected, and unavoidable in a container. A
request without the header gets a 403, so the failure mode if it were ever
exposed is closed rather than open.

`radicale.conf` sets `predefined_collections`, so the first authenticated
request from a user creates `def-calendar` ("Personal Calendar") and
`def-addressbook` ("Personal Address Book"). Without it a new user has no
collections at all and most clients offer no way to create one. Radicale's own
web UI is disabled: it does its own password prompt, which would mean exposing
an unauthenticated route past the proxy.

Storage is plain files under `./radicale-data`, owned by uid/gid 1000 (the
account baked into the image). `init.sh` fixes the ownership if it does not
already match.

### Client setup

Point the client at `https://opencloud.YOURDOMAIN` — the `.well-known`
endpoints handle discovery from there. Username is the OpenCloud username;
the password is an **app token**, not the Authentik password. Most CalDAV
clients cannot do an OIDC browser flow, which is why `PROXY_ENABLE_APP_AUTH`
is on.

Create a token in the Web UI, or from the host:

```bash
# --expiration defaults to 72h, which is far too short for a client that has
# to keep syncing. Pick something long-lived.
docker exec opencloud opencloud auth-app create \
    --user-name=USERNAME --expiration=8760h
```

Tokens are per-client and individually revocable, so use a separate one per
device.

## Migrating calendars and contacts from Nextcloud

Both stacks run in parallel and Nextcloud's DAV data lives in MariaDB, which
this migration never touches — so it is non-destructive and safe to repeat
until the result looks right.

The tool for this is [vdirsyncer](https://vdirsyncer.pimutils.org/), which
syncs CalDAV to CalDAV directly. Do not export to `.ics` and split the file by
hand: recurring events store their overrides as extra `VEVENT`s sharing a UID,
and each event depends on the calendar-level `VTIMEZONE`. Both are easy to get
wrong and the damage is silent.

### 1. Credentials

- **Nextcloud**: Settings -> Security -> "Create new app password".
- **OpenCloud**: an app token (see above). Give it a long expiration.
- Log in to OpenCloud once as the user first, so `def-calendar` and
  `def-addressbook` exist.

### 2. List what is on the Nextcloud side

```bash
docker exec -u www-data nextcloud php occ dav:list-calendars USERNAME
docker exec -u www-data nextcloud php occ dav:list-addressbooks USERNAME
```

### 3. Pre-create the destination collections

Radicale ships one calendar and one address book per user. vdirsyncer is
unreliable at creating collections on Radicale, so make any extras yourself —
one per Nextcloud calendar beyond the first:

```bash
# Calendar
curl -u USERNAME:APP_TOKEN -X MKCALENDAR \
    -H 'Content-Type: application/xml' \
    --data '<?xml version="1.0" encoding="UTF-8"?>
      <C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:set><D:prop><D:displayname>Work</D:displayname></D:prop></D:set>
      </C:mkcalendar>' \
    https://opencloud.YOURDOMAIN/caldav/USERNAME/work/

# Address book
curl -u USERNAME:APP_TOKEN -X MKCOL \
    -H 'Content-Type: application/xml' \
    --data '<?xml version="1.0" encoding="UTF-8"?>
      <D:mkcol xmlns:D="DAV:" xmlns:CR="urn:ietf:params:xml:ns:carddav">
        <D:set><D:prop>
          <D:resourcetype><D:collection/><CR:addressbook/></D:resourcetype>
          <D:displayname>Work Contacts</D:displayname>
        </D:prop></D:set>
      </D:mkcol>' \
    https://opencloud.YOURDOMAIN/carddav/USERNAME/work-contacts/
```

The last path segment is the collection id used in the vdirsyncer mapping
below; the displayname is what clients show.

### 4. vdirsyncer config

`~/.config/vdirsyncer/config`:

```ini
[general]
status_path = "~/.local/share/vdirsyncer/status/"

[pair calendars]
a = "nc_cal"
b = "oc_cal"
# [shortname, collection on a, collection on b] — one row per calendar.
# The Nextcloud id comes from `occ dav:list-calendars`, the OpenCloud one is
# the path segment used at MKCALENDAR time.
collections = [["personal", "personal", "def-calendar"],
               ["work", "work", "work"]]
# Nextcloud is authoritative: this is a one-way migration, not a merge.
conflict_resolution = "a wins"

[storage nc_cal]
type = "caldav"
url = "https://drive.YOURDOMAIN/remote.php/dav/"
username = "USERNAME"
password = "NEXTCLOUD_APP_PASSWORD"

[storage oc_cal]
type = "caldav"
# The explicit /caldav/ path, not the bare host: let vdirsyncer talk to
# Radicale directly rather than round-tripping through .well-known.
url = "https://opencloud.YOURDOMAIN/caldav/"
username = "USERNAME"
password = "OPENCLOUD_APP_TOKEN"

[pair contacts]
a = "nc_card"
b = "oc_card"
collections = [["personal", "contacts", "def-addressbook"]]
conflict_resolution = "a wins"

[storage nc_card]
type = "carddav"
url = "https://drive.YOURDOMAIN/remote.php/dav/"
username = "USERNAME"
password = "NEXTCLOUD_APP_PASSWORD"

[storage oc_card]
type = "carddav"
url = "https://opencloud.YOURDOMAIN/carddav/"
username = "USERNAME"
password = "OPENCLOUD_APP_TOKEN"
```

### 5. Run it

```bash
vdirsyncer discover     # confirms it can see both sides
vdirsyncer metasync     # displaynames and colours
vdirsyncer sync         # the events and contacts
```

`discover` prompts before touching anything; read what it reports before
saying yes. If a collection mapping is wrong it will offer to create something
unexpected — answer no and fix `collections`.

### 6. Verify, then stop syncing

Check counts on both sides, then spot-check a recurring event with a modified
occurrence and an all-day event, since those are where iCalendar handling
usually breaks.

When the result is right, **delete the vdirsyncer config and status
directory**. Leaving it in place risks a later run propagating OpenCloud
changes back into Nextcloud, or resurrecting Nextcloud entries you deleted in
OpenCloud. Move clients over to `https://opencloud.YOURDOMAIN`, and only then
consider retiring Nextcloud's calendar and contacts.

### Alternative without vdirsyncer

Export each calendar from the Nextcloud Calendar app (`... -> Export`, or
`GET https://drive.YOURDOMAIN/remote.php/dav/calendars/USER/CAL/?export`) and
import the `.ics` into the OpenCloud calendar from Thunderbird, which is
subscribed to both. Slower and manual, but Thunderbird parses iCalendar
correctly, which is the part that matters.

## Backup considerations

Unlike Nextcloud (MariaDB + filesystem), OpenCloud uses embedded storage
(boltdb + files under `./data`). `pre-backup.sh` stops the `opencloud` and
`radicale` containers so their data directories are consistent for
snapshotting; `post-backup.sh` starts them again. Radicale is included because
its collections are plain files written in place with no transactional store.
Collabora and the collaboration service stay running — they are stateless.

## Parallel-with-Nextcloud notes

- OpenCloud lives on `opencloud.YOURDOMAIN`; Nextcloud stays on
  `drive.YOURDOMAIN`. No conflicts.
- Each stack has its own Collabora; the two never share a WOPI host.
- Calendars and contacts exist on both sides until they are migrated (see
  above). Nextcloud keeps serving them read-write in the meantime — nothing
  here disables them.
- When Nextcloud is eventually retired, this stack stands on its own — nothing
  in `opencloud/` references the Nextcloud stack.
