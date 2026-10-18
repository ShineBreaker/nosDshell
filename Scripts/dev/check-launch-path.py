#!/usr/bin/env python3
"""One launch path for desktop entries.

Launching a DesktopEntry honours customLaunchPrefix / terminalCommand /
runInTerminal. That logic lives in exactly one place —
CompositorService.launchDesktopEntry (upstream #2435). It used to be
copy-pasted into the launcher, dock and taskbar; the copies diverged
(broken argv splits on repeated spaces, missing quoted-args branch).
This check fails when any of the three keys is read outside the launch
helper, the settings declaration, or the settings UI tab that edits them.

Usage:
  Scripts/dev/check-launch-path.py    # exit 1 on any hit
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ALLOWED = {
    Path("Services/Compositor/CompositorService.qml"),
    Path("Commons/Settings.qml"),
}
ALLOWED_DIRS = (Path("Modules/Panels/Settings"),)
KEYS = re.compile(r"customLaunchPrefix|terminalCommand|runInTerminal")


def main():
    hits = []
    for path in ROOT.rglob("*.qml"):
        rel = path.relative_to(ROOT)
        if rel in ALLOWED or any(part in {"references", ".git"} for part in rel.parts):
            continue
        # Bundled plugins own their settings schema — e.g. usb-drive-manager's
        # plugin-level "terminalCommand" is not the shell launch-pipeline key.
        if rel.parts[0] == "Assets" and rel.parts[1] == "Plugins":
            continue
        if any(rel.is_relative_to(d) for d in ALLOWED_DIRS):
            continue
        for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            code = line.split("//", 1)[0]
            if KEYS.search(code):
                hits.append(f"{rel}:{n}")
    if hits:
        for h in hits:
            print(f"launch path read: {h} — launch via CompositorService.launchDesktopEntry(app)")
        return 1
    print("launch path ok: launch keys only read in CompositorService.launchDesktopEntry")
    return 0


if __name__ == "__main__":
    sys.exit(main())
