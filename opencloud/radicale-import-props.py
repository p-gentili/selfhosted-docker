#!/usr/bin/env python3
"""Copy collection metadata from Nextcloud onto Radicale's stored properties.

vdirsyncer moves items, not metadata. `metasync` carries displayname and colour
but NOT `supported-calendar-component-set`, so migrated collections end up named
after their (often UUID) collection id and declaring no component set at all —
which makes iOS list every one of them in both Calendar and Reminders.

This reads the real properties from Nextcloud over DAV and writes them into
Radicale's `.Radicale.props` files, matching collections by id.

Radicale must be STOPPED while this runs: it caches collection metadata, and a
concurrent write would be lost or read half-applied.

    docker compose -f opencloud/docker-compose.yml stop radicale
    ./radicale-import-props.py --url https://drive.example.com --user NAME \
        --radicale-data opencloud/radicale-data          # dry run
    ./radicale-import-props.py ... --apply
    docker compose -f opencloud/docker-compose.yml start radicale

Nothing is written without --apply. With it, every .Radicale.props touched is
first copied to .Radicale.props.bak.
"""

import argparse
import base64
import getpass
import json
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {
    "d": "DAV:",
    "c": "urn:ietf:params:xml:ns:caldav",
    "cr": "urn:ietf:params:xml:ns:carddav",
    "ical": "http://apple.com/ns/ical/",
}

# DAV property -> the key Radicale uses in .Radicale.props. Verified against
# radicale/sharing/__init__.py OVERLAY_PROPERTIES_WHITELIST.
CAL_PROPS = {
    "displayname": "D:displayname",
    "calendar-description": "C:calendar-description",
    "calendar-color": "ICAL:calendar-color",
}
CARD_PROPS = {
    "displayname": "D:displayname",
    "addressbook-description": "CR:addressbook-description",
}

PROPFIND_CAL = """<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
            xmlns:ical="http://apple.com/ns/ical/">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <c:supported-calendar-component-set/>
    <c:calendar-description/>
    <ical:calendar-color/>
  </d:prop>
</d:propfind>"""

PROPFIND_CARD = """<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:cr="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <cr:addressbook-description/>
  </d:prop>
</d:propfind>"""


def propfind(url, user, password, body):
    req = urllib.request.Request(url, data=body.encode(), method="PROPFIND")
    cred = base64.b64encode(f"{user}:{password}".encode()).decode()
    req.add_header("Authorization", f"Basic {cred}")
    req.add_header("Depth", "1")
    req.add_header("Content-Type", "application/xml; charset=utf-8")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return ET.fromstring(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"PROPFIND {url} failed: {e.code} {e.reason}")
    except urllib.error.URLError as e:
        sys.exit(f"PROPFIND {url} failed: {e.reason}")


def text_of(prop, path):
    el = prop.find(path, NS)
    if el is None or el.text is None or not el.text.strip():
        return None
    return el.text.strip()


def parse_collections(root, kind):
    """Yield (collection_id, {radicale prop key: value}) for real collections."""
    wanted = "c:calendar" if kind == "calendar" else "cr:addressbook"
    mapping = CAL_PROPS if kind == "calendar" else CARD_PROPS

    for resp in root.findall("d:response", NS):
        href = text_of(resp, "d:href")
        if not href:
            continue
        # Only 200 propstats carry real values; a 404 propstat lists absent props.
        prop = None
        for ps in resp.findall("d:propstat", NS):
            status = text_of(ps, "d:status") or ""
            if " 200 " in status:
                prop = ps.find("d:prop", NS)
                break
        if prop is None:
            continue
        if prop.find(f"d:resourcetype/{wanted}", NS) is None:
            continue  # the principal/home itself, or the wrong kind

        props = {}
        for dav_name, rad_key in mapping.items():
            ns = "d" if dav_name == "displayname" else ("cr" if dav_name.startswith("addressbook") else ("ical" if dav_name.endswith("color") else "c"))
            val = text_of(prop, f"{ns}:{dav_name}")
            if val:
                props[rad_key] = val

        if kind == "calendar":
            comps = [
                c.get("name")
                for c in prop.findall("c:supported-calendar-component-set/c:comp", NS)
                if c.get("name")
            ]
            if comps:
                props["C:supported-calendar-component-set"] = ",".join(comps)

        cid = href.rstrip("/").rsplit("/", 1)[-1]
        yield urllib.parse.unquote(cid), props


def collection_root(data_dir):
    root = Path(data_dir) / "collections" / "collection-root"
    if not root.is_dir():
        sys.exit(f"no collection root under {root}")
    users = sorted(p for p in root.iterdir() if p.is_dir())
    if not users:
        sys.exit(f"no user directories under {root}")
    if len(users) > 1:
        sys.exit(
            "multiple users found; this script handles one at a time:\n  "
            + "\n  ".join(u.name for u in users)
        )
    return users[0]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", required=True, help="Nextcloud base URL, e.g. https://drive.example.com")
    ap.add_argument("--user", required=True, help="Nextcloud username")
    ap.add_argument("--password", help="Nextcloud app password (prompted if omitted)")
    ap.add_argument("--radicale-data", required=True, help="path to opencloud/radicale-data")
    ap.add_argument("--apply", action="store_true", help="write changes (default: dry run)")
    args = ap.parse_args()

    password = args.password or getpass.getpass("Nextcloud app password: ")
    base = args.url.rstrip("/")

    source = {}
    source.update(dict(parse_collections(
        propfind(f"{base}/remote.php/dav/calendars/{args.user}/", args.user, password, PROPFIND_CAL),
        "calendar")))
    source.update(dict(parse_collections(
        propfind(f"{base}/remote.php/dav/addressbooks/users/{args.user}/", args.user, password, PROPFIND_CARD),
        "addressbook")))

    if not source:
        sys.exit("Nextcloud returned no collections — check --user and the app password")

    user_dir = collection_root(args.radicale_data)
    print(f"Radicale user {user_dir.name}\n")

    changed = unmatched_local = 0
    seen = set()
    for coll in sorted(p for p in user_dir.iterdir() if p.is_dir()):
        props_file = coll / ".Radicale.props"
        current = {}
        if props_file.is_file():
            try:
                current = json.loads(props_file.read_text())
            except json.JSONDecodeError:
                print(f"  {coll.name}: unreadable .Radicale.props, skipped")
                continue

        incoming = source.get(coll.name)
        if incoming is None:
            print(f"  {coll.name}: no match in Nextcloud, left alone")
            unmatched_local += 1
            continue
        seen.add(coll.name)

        # Never touch `tag` — it is what makes the collection a calendar or an
        # address book, and Nextcloud has no equivalent property to copy.
        updates = {k: v for k, v in incoming.items() if current.get(k) != v}
        if not updates:
            print(f"  {coll.name}: already matches")
            continue

        label = incoming.get("D:displayname", coll.name)
        print(f"  {coll.name} -> {label}")
        for k, v in sorted(updates.items()):
            print(f"      {k}: {current.get(k)!r} -> {v!r}")
        changed += 1

        if args.apply:
            if props_file.is_file():
                shutil.copy2(props_file, props_file.with_suffix(".props.bak"))
            merged = {**current, **updates}
            props_file.write_text(json.dumps(merged))

    missing = sorted(set(source) - seen)
    if missing:
        print("\nIn Nextcloud but not in Radicale (not created by vdirsyncer?):")
        for m in missing:
            print(f"  {m}")

    print(f"\n{changed} collection(s) to update, {unmatched_local} local left alone")
    if changed and not args.apply:
        print("Dry run — re-run with --apply to write.")


if __name__ == "__main__":
    main()
