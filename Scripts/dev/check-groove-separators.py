#!/usr/bin/env python3
"""Ban hand-drawn DDE groove separators.

The menu separator groove (DESIGN §3.3 — 1 px black x 0.1 over 1 px
white x 0.1) lives in exactly two places: the `grooveShadow`/`grooveLine`
tokens in Commons/Colors.qml and NDivider's "ddeGroove" variant. The pair
was inlined five times before convergence; this check fails on the raw
literals anywhere else so the next copy gets caught at lint time.

Usage:
  Scripts/dev/check-groove-separators.py    # exit 1 on any hit
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ALLOWED = {Path("Commons/Colors.qml"), Path("Widgets/NDivider.qml")}
LITERALS = re.compile(r"Qt\.rgba\(\s*(0|1)\s*,\s*\1\s*,\s*\1\s*,\s*0\.1\s*\)")


def main():
    hits = []
    for path in ROOT.rglob("*.qml"):
        rel = path.relative_to(ROOT)
        if rel in ALLOWED or any(part in {"references", ".git"} for part in rel.parts):
            continue
        for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            code = line.split("//", 1)[0]
            if LITERALS.search(code):
                hits.append(f"{rel}:{n}")
    if hits:
        for h in hits:
            print(f"inline groove literal: {h} — use NDivider {{ variant: \"ddeGroove\" }}")
        return 1
    print("groove separators ok: literals only in Colors.qml tokens + NDivider")
    return 0


if __name__ == "__main__":
    sys.exit(main())
