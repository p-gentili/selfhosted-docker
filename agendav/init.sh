#!/bin/bash

set -e

DIRNAME=$(dirname "$(realpath "$0")")
COMPOSE=$DIRNAME/docker-compose.yml
source $DIRNAME/.env

# Both secrets are per-installation and must never keep the sample value:
# csrf.secret protects the login form, and session.encryption.key is what
# encrypts the OpenCloud app token held in every session.
for var in AGENDAV_CSRF_SECRET AGENDAV_SESSION_KEY; do
    if [ -z "${!var}" ] || [ "${!var}" = "changeme" ]; then
        echo "$var is unset or still the sample value in .env." >&2
        echo "Generate one with: openssl rand -hex 32" >&2
        exit 1
    fi
done

mkdir -p "$DIRNAME/data" "$DIRNAME/var"

# AgenDAV publishes no image to any registry, so the source is cloned here and
# built from ./src by docker compose, using upstream's own production
# Dockerfile. Bump this to upgrade.
AGENDAV_VERSION=3.3.1
SRC=$DIRNAME/src

if [ ! -d "$SRC/.git" ]; then
    git clone --depth 1 --branch "$AGENDAV_VERSION" \
        https://github.com/agendav/agendav.git "$SRC"
else
    git -C "$SRC" fetch --depth 1 --force origin \
        "refs/tags/$AGENDAV_VERSION:refs/tags/$AGENDAV_VERSION"
    git -C "$SRC" checkout --quiet --force "$AGENDAV_VERSION"
fi

# Upstream's production Dockerfile runs `chmod -R 750 /app/var`, but var/ holds
# only generated files and its .gitkeep was deleted in ae1c3504 ("fix(docker):
# Ensure write access to var dir") without updating that Dockerfile — so the
# directory is missing from a clean checkout and the build fails there. Their
# CI never builds this Dockerfile, so it shipped broken in 3.3.0. Recreating
# the directory is the entire fix, and keeps upstream's Dockerfile usable
# unmodified.
mkdir -p "$SRC/var"

# Second bug in the same Dockerfile: package.json defines the asset build as
# four steps (build:assets = templates + copy + css + js), but the Dockerfile
# runs only three, skipping build:copy. That step is what copies the icon
# fonts out of node_modules — Font Awesome and Bootstrap glyphicons — plus the
# fullcalendar locales and jquery-ui theme images. All of them are gitignored,
# so they exist nowhere else, and the compiled CSS then requests
# ../../font/fa/fontawesome-webfont.woff2 and friends, which 404: every
# calendar icon renders broken.
#
# Insert the missing step rather than vendoring their Dockerfile. The guard
# makes an upstream change to this line a loud failure instead of silently
# returning broken icons; the grep makes it a no-op once upstream fixes it.
if ! grep -q 'npm run build:copy' "$SRC/Dockerfile"; then
    if ! grep -q '&& npm run build:css \\' "$SRC/Dockerfile"; then
        echo "$SRC/Dockerfile: expected '&& npm run build:css \\' not found." >&2
        echo "Upstream changed the asset build; re-check it before bumping." >&2
        exit 1
    fi
    sed -i 's|&& npm run build:css \\|\&\& npm run build:copy \\\n    \&\& npm run build:css \\|' \
        "$SRC/Dockerfile"
fi

# Render the config. settings.php is generated rather than tracked because it
# carries both secrets; changes belong in settings.template.php. The explicit
# variable list keeps envsubst from touching anything else in the file.
export AGENDAV_SITE_TITLE AGENDAV_TIMEZONE OPENCLOUD_FQDN \
    AGENDAV_CSRF_SECRET AGENDAV_SESSION_KEY
envsubst '${AGENDAV_SITE_TITLE} ${AGENDAV_TIMEZONE} ${OPENCLOUD_FQDN} ${AGENDAV_CSRF_SECRET} ${AGENDAV_SESSION_KEY}' \
    < "$DIRNAME/settings.template.php" > "$DIRNAME/settings.php"
chmod 640 "$DIRNAME/settings.php"

# Apache runs its workers as www-data (uid/gid 33) inside the container, while
# bind mounts arrive owned by the host user. Only chown when it is actually
# wrong, so the common case never prompts for sudo.
for path in "$DIRNAME/data" "$DIRNAME/var" "$DIRNAME/settings.php"; do
    # Test the contents, not just the top-level directory: an earlier release
    # ran the migrations as root, which left a root-owned agendav.sqlite
    # inside an already-correct data/. Checking only the directory would skip
    # it, and Apache's workers would still be unable to write the database.
    if [ -n "$(find "$path" \( ! -user 33 -o ! -group 33 \) -print -quit 2>/dev/null)" ]; then
        sudo chown -R 33:33 "$path"
    fi
done

# --build because there is no published image to pull: the compose file builds
# upstream's Dockerfile from a pinned git tag.
docker compose -f $COMPOSE down
docker compose -f $COMPOSE up -d --build

# Create or update the schema. The CLI exits 255 when config/settings.php is
# missing, so this has to follow the render above.
#
# --user www-data because the image declares no default user: a plain `exec`
# runs as root and creates agendav.sqlite root-owned, after which Apache's
# workers can read the database but not write it, and every request 500s.
docker compose -f $COMPOSE exec -T --user www-data agendav \
    php bin/agendavcli migrations:migrate -n
