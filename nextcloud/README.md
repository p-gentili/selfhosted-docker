# Nextcloud
Official website: [https://nextcloud.com](https://nextcloud.com)

Github: [https://github.com/nextcloud](https://github.com/nextcloud)

## Collabora CODE
Official website: [https://www.collaboraoffice.com/code/](https://www.collaboraoffice.com/code/)

## OIDC SSO via Authentik

Nextcloud uses the official `user_oidc` app to delegate login to Authentik.

### Prerequisites
- Authentik is running at `https://auth.YOURDOMAIN`
- An OAuth2/OpenID provider + application named `nextcloud` exist in Authentik
  (slug = `nextcloud`, redirect URI = `https://drive.YOURDOMAIN/apps/user_oidc/code`)
- You have copied the **Client ID** and **Client Secret** from the provider

### One-time configuration
Run from the host (replace the placeholders):

```bash
# Install + enable the OIDC app
docker exec -u www-data nextcloud php occ app:install user_oidc
docker exec -u www-data nextcloud php occ app:enable  user_oidc

# Register Authentik as a provider.
# `preferred_username` + `unique-uid=0` makes the Nextcloud UID equal the Authentik
# username verbatim, so SSO logins link to an existing local account whose username
# matches. Don't rename users in Authentik after linking — it would orphan their data.
docker exec -u www-data nextcloud php occ user_oidc:provider Authentik \
    --clientid="<CLIENT_ID>" \
    --clientsecret="<CLIENT_SECRET>" \
    --discoveryuri="https://auth.YOURDOMAIN/application/o/nextcloud/.well-known/openid-configuration" \
    --scope="openid email profile" \
    --mapping-uid=preferred_username \
    --mapping-display-name=name \
    --mapping-email=email \
    --unique-uid=0

# (Optional) Hide the local-login form so the SSO button is the default
docker exec -u www-data nextcloud php occ config:app:set --value=0 user_oidc allow_multiple_user_backends
```

### Linking your existing Nextcloud user to Authentik
The provider config above uses the `preferred_username` claim as the Nextcloud UID
(unhashed). So as long as your Authentik user's **Username** field exactly equals an
existing Nextcloud username (check with `occ user:list`), the first SSO login attaches
to that existing account instead of creating a new one.

### Recovering local admin login
If SSO is misconfigured and you locked yourself out, append `?direct=1` to the login URL:
`https://drive.YOURDOMAIN/login?direct=1` — that bypasses the OIDC redirect and shows the
classic username/password form.

