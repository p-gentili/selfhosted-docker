# Samba

Github: [https://github.com/ServerContainers/samba](https://github.com/ServerContainers/samba)

Exposes the photo library as an SMB share (`photos`) on the LAN. Not proxied by
Caddy - it publishes port 445 directly and is reachable by IP only.

A single account is allowed on the share. Its name, password, UID and the
share's `valid users` are all driven by `SMB_USER` / `SMB_PASSWORD` in `.env`,
so no other account can connect.

## Configuration

Copy `.env.sample` to `.env` and set `SMB_USER` and `SMB_PASSWORD` before the
first run. Both are mandatory - Compose fails with an explicit message rather
than starting a stack with a broken or password-less account.

Two values must agree with the host or the share will misbehave in ways that
are not obvious:

- `SMB_PHOTOS_DIR` must be the **real mount point** of the external drive. If it
  points at a path that is not mounted, Docker silently creates an empty
  directory and the share comes up healthy but empty.
- `SMB_UID` must be the UID owning `SMB_PHOTOS_DIR`. The container account is
  created with that UID, so files written over SMB are owned correctly. If it
  does not match, clients get read-only behaviour despite `read only = no`.

Because the bind mount depends on the external drive, the corresponding
`/etc/fstab` entry should carry `nofail` so a missing drive fails loudly at
mount time instead of silently exporting an empty share.

## Connecting

```
smb://<SMB_USER>@<host-ip>/photos
```

Include the username in the URL. GVFS/Nautilus otherwise defaults to the local
Unix username, and if that contains an `@` (as Canonical SSO usernames do)
libsmbclient reads it as a Kerberos principal and fails with `Invalid argument`
before ever prompting for a password.

The client host also needs `samba-common` installed, and a `netbios name` of at
most 15 characters set in `/etc/samba/smb.conf` if its hostname is longer.
