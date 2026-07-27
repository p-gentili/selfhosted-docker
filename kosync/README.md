# KOReader Sync Server

Official KOReader progress-sync server (kosync).
Github: [https://github.com/koreader/koreader-sync-server](https://github.com/koreader/koreader-sync-server)

Served at `kosync.${DOMAIN}`. It syncs reading positions across your KOReader
devices. The image bundles OpenResty and Redis in a single container; all state
lives in the bind-mounted `./data/redis`.

Behind Caddy (which terminates TLS) the server is reached on its plain-HTTP
port `17200`; the self-signed HTTPS port `7200` is not used.

## KOReader client setup

In KOReader: **Tools → Progress sync → Custom sync server** and set:

```
https://kosync.${DOMAIN}
```

Then use **Register** (first time) / **Login**, and enable **Push/pull progress**.

## Registration

Account registration is disabled by default (`ENABLE_USER_REGISTRATION=false`)
since the server is internet-facing. To create your account the first time:

```bash
cp .env.sample .env          # first run only
# edit .env: ENABLE_USER_REGISTRATION=true
docker compose up -d
# register your account from KOReader, then:
# edit .env: ENABLE_USER_REGISTRATION=false
docker compose up -d
```

## Backup

Reading-progress data is held by the bundled Redis. `pre-backup.sh` stops the
container so Redis flushes a consistent snapshot to `./data/redis`;
`post-backup.sh` starts it again. Both run automatically via the repo-wide
`pre-backup-all.sh` / `post-backup-all.sh`.
