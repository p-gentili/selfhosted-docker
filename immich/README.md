# Immich
Official website: [https://immich.app/](https://immich.app/)

Github: [https://github.com/immich-app/immich](https://github.com/immich-app/immich)

## Sign-in with Authentik

Immich's OAuth is configured in its admin UI and stored in its database, not in
this repo.

1. **In Authentik:** *Applications > Providers > Create > OAuth2/OpenID
   Provider*:
   - Name: `immich`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs (all Strict, type Authorization):
     - `app.immich:///oauth-callback` (mobile app, three slashes)
     - `https://photos.DOMAIN/auth/login`
     - `https://photos.DOMAIN/user-settings`
   - Signing Key: `authentik Self-signed Certificate`. **This is required.**
     Immich expects RS256, and without a key Authentik signs with HS256.
   - Note the **Client ID** and **Client Secret**.

   Then *Applications > Applications > Create*: Name `Immich`, Slug `immich`,
   Provider `immich`, Launch URL
   `https://photos.DOMAIN/auth/login?autoLaunch=1`.
2. **In Immich:** *Administration > Settings > Authentication Settings >
   OAuth*:
   - Issuer URL: `https://auth.DOMAIN/application/o/immich/` (trailing slash)
   - Client ID / Client Secret: from step 1
   - Scope `openid email profile` and signing algorithm `RS256` (the defaults)
   - Storage Label Claim: `immich_storage_label`. Authentik doesn't send it, so
     existing storage labels (the upload folder names) are left alone. The
     default `preferred_username` would rename them for new users.
   - Role Claim: leave at `immich_role`. Authentik doesn't send it either, so
     admin flags stay as set in Immich.
   - Button Text: `Login with Authentik`; Auto Register: on; Mobile Redirect
     URI Override: off.
   - Keep **Password Login** on as the way in when Authentik is down.

An Authentik login whose email matches an existing Immich user is linked to
that user, so existing accounts keep their library and admin rights. With Auto
Launch on, `/auth/login?autoLaunch=0` still shows the password form.
