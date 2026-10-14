#!/usr/bin/env python3
"""Check the migration registry is wired completely.

Three sets must agree, and the stamped version must be registered:

1. Migration files: Commons/Migrations/Migration<N>.qml that exist.
2. Component declarations: `property Component migration<N>Component`
   lines in Commons/Migrations/MigrationRegistry.qml.
3. Registry map entries: `<N>: migration<N>Component` lines in the
   registry's `migrations` map — the only thing runVersionedMigrations
   actually iterates.
4. Commons/Settings.qml `settingsVersion: <V>` must equal the highest
   registered key: bumping the version without registering the migration
   stamps every config with a version whose migration never runs
   (Migration82 shipped exactly this way and needed a re-run migration
   to recover; AGENTS.md, migration rules in CODING_STANDARDS.md).

Any mismatch fails with the offending numbers listed.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
MIGRATIONS_DIR = REPO / "Commons" / "Migrations"
REGISTRY = MIGRATIONS_DIR / "MigrationRegistry.qml"
SETTINGS = REPO / "Commons" / "Settings.qml"


def main() -> int:
    files = {int(m.group(1)) for m in
             (re.fullmatch(r"Migration(\d+)\.qml", p.name) for p in MIGRATIONS_DIR.glob("*.qml"))
             if m}

    registry_src = REGISTRY.read_text(encoding="utf-8")
    declared = {int(m.group(1)) for m in
                re.finditer(r"property Component migration(\d+)Component", registry_src)}
    # Only `N: migrationNComponent` pairs count as registered — a bare
    # component property (like the v82 bug) is never run.
    registered = {int(m.group(1)) for m in
                  re.finditer(r"(\d+):\s*migration(\d+)Component", registry_src)
                  if m.group(1) == m.group(2)}

    settings_src = SETTINGS.read_text(encoding="utf-8")
    version_match = re.search(r"settingsVersion:\s*(\d+)", settings_src)
    if version_match is None:
        print("FAIL: no `settingsVersion:` found in Commons/Settings.qml")
        return 1
    version = int(version_match.group(1))

    ok = True
    for label, extra in (
        ("declared but not registered (migration will never run)", declared - registered),
        ("registered but not declared", registered - declared),
        ("file present but not declared", files - declared),
        ("declared but no file", declared - files),
    ):
        if extra:
            ok = False
            print(f"FAIL: {label}: {sorted(extra)}")
    if registered and version != max(registered):
        ok = False
        print(f"FAIL: settingsVersion={version} but highest registered migration is "
              f"{max(registered)} — the version stamp must track the registry")

    if ok:
        print(f"migration registry ok: {len(registered)} migrations, settingsVersion={version}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
