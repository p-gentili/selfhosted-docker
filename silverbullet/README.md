# SilverBullet
Github: [https://github.com/silverbulletmd/silverbullet](https://github.com/silverbulletmd/silverbullet)

Served at `notes.${DOMAIN}`. Notes live in the bind-mounted `./data` (mounted at `/space`).

## Authentication

SilverBullet's built-in login is enabled via the `SB_USER` env var, in
`username:password` form. Copy the sample env file and set your credentials:

```bash
cp .env.sample .env
# edit .env and set SB_USER=you:yourpassword
```

Visiting `https://notes.${DOMAIN}` then prompts for these credentials.
