#!/usr/bin/env python3
"""List Radicale collections: type, component set, item count."""
import json, sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else "radicale-data") / "collections" / "collection-root"
if not root.is_dir():
    sys.exit(f"no collection root under {root}")

for user in sorted(p for p in root.iterdir() if p.is_dir()):
    print(f"\nuser {user.name}")
    print(f"  {'collection':<28} {'kind':<12} {'components':<22} items")
    print(f"  {'-'*28} {'-'*12} {'-'*22} -----")
    for c in sorted(p for p in user.iterdir() if p.is_dir()):
        props = {}
        f = c / ".Radicale.props"
        if f.is_file():
            try:
                props = json.loads(f.read_text())
            except json.JSONDecodeError:
                props = {"tag": "<unreadable props>"}
        tag = props.get("tag", "?")
        kind = {"VCALENDAR": "calendar", "VADDRESSBOOK": "addressbook"}.get(tag, tag)
        comps = props.get("C:supported-calendar-component-set")
        if tag == "VADDRESSBOOK":
            comps = "-"
        elif not comps:
            comps = "(unset -> BOTH apps)"
        n = sum(1 for i in c.iterdir() if i.suffix in (".ics", ".vcf"))
        name = props.get("D:displayname", c.name)
        print(f"  {name[:28]:<28} {kind:<12} {comps:<22} {n}")
