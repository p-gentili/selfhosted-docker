# Nextcloud → OpenCloud files migration

## Goal

Move the personal files from the Nextcloud stack into OpenCloud, make OpenCloud the
primary for files, and freeze Nextcloud's files so the two can never diverge. Nextcloud
keeps running for calendar and contacts, which stay read-write.

This is deliberately not a retirement of Nextcloud. Calendar/contacts have no home in
OpenCloud today — OpenCloud offers them through a separate Radicale integration, with
native groupware slated for 2026 — so that decision is deferred.

## Current state

Measured on the live instance rather than assumed:

| | |
|---|---|
| `pgentili` files | 3.5 GB, last active 2026-08-07 |
| File cache rows under `files/` | 2,626 |
| Versions / trash rows | 325 / 371 |
| Calendars / events | 14 / 1,381 |
| Address books / contacts | 3 / 393 |
| Shares | 1 |
| Second account (OIDC, idle since 2026-05-07) | 62 MB |
| Free space on `/srv` | 201 GB |

Two preconditions were verified, because they are what make the chosen approach safe:

- **Server-side encryption is disabled**, so files on disk are plaintext.
- **No external storage is configured** (the app isn't even installed), so nothing lives
  outside the data directory.

Together these mean the on-disk tree is identical to what Nextcloud shows, and can be
read directly. If either were false, the approach below would be wrong and the
WebDAV-to-WebDAV path would be required instead.

Calendars and contacts are stored in the database (`oc_calendarobjects`, `oc_cards`), not
the data directory. This is the fact the whole design rests on: freezing files on disk
cannot affect them.

## Approach

`rclone copy` from the Nextcloud data directory into OpenCloud over WebDAV.

The alternative — WebDAV on both ends, which is what [OpenCloud's official
guide](https://docs.opencloud.eu/docs/admin/maintenance/migrate/) documents — was
rejected for this instance. It needs a second credential and pulls every byte through
PHP, and its one real advantage (copying Nextcloud's logical view regardless of storage
backend) is worth nothing here, since encryption and external storage are both off. It
remains the fallback if the pre-flight count check disagrees.

The OpenCloud desktop client was rejected outright: GUI-driven on a headless host, with
no verification pass.

## Sequence

Ordering is the part that matters. **Freeze before copy.** If Nextcloud stays writable
during the transfer, a file edited mid-copy arrives in an indeterminate state and the
verification pass cannot detect it. Freezing first makes the source immutable, so the
copy is a snapshot.

1. **Prep OpenCloud** — set `PROXY_ENABLE_APP_AUTH=true`, redeploy, mint an app token
   for `pgentili`.
2. **Baseline** — count files and bytes on disk; reconcile against the file cache's
   2,626 rows. A disagreement here means falling back to the WebDAV-to-WebDAV approach.
3. **Freeze** — mount each user's `files/` read-only, recreate the container, confirm
   calendar and contacts still accept writes.
4. **Copy** — `rclone copy` from disk to OpenCloud's personal space root.
5. **Verify** — see below.
6. **Clean up** — revoke the app token.

## Components

### OpenCloud configuration

The `auth-app` service already runs inside the single binary; it only needs the proxy
flag to start issuing tokens:

```yaml
PROXY_ENABLE_APP_AUTH: "true"
```

This is a real configuration change and belongs in `opencloud/docker-compose.yml`, not
in an ad-hoc command.

### The copy

rclone runs from its official container image rather than being installed on the host,
matching how everything else on this box works, and letting the source be mounted `:ro`
as a second guarantee on top of the freeze.

```
[opencloud]
type = webdav
url = https://opencloud.home.pgentili.com/remote.php/webdav
vendor = opencloud
user = pgentili
pass = <rclone obscure'd app token>
```

`vendor = opencloud` is required — the generic WebDAV vendor mishandles some of
OpenCloud's responses.

The app token is a credential: it lives in an untracked file and is revoked in step 6.
It must not reach git.

### The freeze

A nested read-only bind mount layered over the existing one, in
`nextcloud/docker-compose.yml`:

```yaml
volumes:
  - ./nextcloud:/var/www/html
  - ./nextcloud/data/<user>/files:/var/www/html/data/<user>/files:ro
```

Docker resolves the more specific path last, so `files/` becomes read-only while
`uploads/`, `cache/`, `files_versions/`, `appdata_*` and the log stay writable and the
database is untouched. Applied to both accounts, so "Nextcloud files are frozen" holds
without exceptions.

Nextcloud has no concept of a read-only data directory, so write attempts fail at the
filesystem and surface as generic errors in the Files UI plus noise in the log, rather
than a graceful message. That is accepted. The polished alternative — an app-level
access-control rule — is leakier, which is the wrong trade for a mechanism whose only
job is to guarantee nothing changes.

## Verification

- `rclone check` between source and destination. Over WebDAV this compares size and
  modification time, **not** content hashes, so on its own it proves nothing was skipped
  or truncated — not that every byte matches. `--download` forces a true byte-for-byte
  comparison and costs only minutes at this size, so it is used.
- File counts reconciled three ways: disk, the cache's 2,626 rows, and what OpenCloud
  reports.
- Open several documents in OpenCloud and Collabora, deliberately including a large file
  and a deeply nested path, since that is where size and path bugs surface.
- Write to calendar and contacts from a DAV client after the freeze, confirming the
  files/DAV split actually holds.

## Rollback

Nextcloud is never modified. Its data directory is only ever read, and the single change
to that stack is a mount flag, so rollback is deleting one line and recreating the
container.

If the copy itself is wrong, delete the files from OpenCloud's personal space and re-run.
They will sit in OpenCloud's trash until it is emptied, so reclaimed space is not
immediate.

## Out of scope

Listed as non-migrating in OpenCloud's own guide: file versions (325), trash (371), the
single share, public links, project spaces, and metadata/tags.

Also excluded by choice: the second account's 62 MB, and calendar/contacts/tasks/notes,
which stay in Nextcloud read-write. Nextcloud is not retired.
