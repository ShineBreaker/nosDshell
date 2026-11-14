#!/usr/bin/env python3
"""Guard against the docs-sync CI failure mode: the generated settings
reference block in docs/legacy/getting-started/nixos.md drifts from
Assets/settings-default.json when keys are added/removed without
regenerating docs/legacy (the full vendor script needs a network clone,
so lint can only approximate the check locally).

Compares the SET of key names: any name in the JSON but missing from the
generated block (added key, stale doc) or vice versa (removed key, stale
doc) fails with a regenerate reminder. Value-only drift is not covered —
CI still runs the authoritative full regeneration + diff.
"""

import json
import re
import sys

DOC = "docs/legacy/getting-started/nixos.md"
DEFAULTS = "Assets/settings-default.json"
MARKER = "complete settings reference"


def json_keys(obj, acc):
    if isinstance(obj, dict):
        for k, v in obj.items():
            acc.add(k)
            json_keys(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            json_keys(v, acc)
    return acc


def main():
    doc = open(DOC, encoding="utf-8").read()
    try:
        block = re.search(r"```\w*\n(.*?)```", doc[doc.index(MARKER):], re.S).group(1)
    except (ValueError, AttributeError):
        print(f"{DOC}: settings reference block not found", file=sys.stderr)
        return 1

    doc_keys = set(re.findall(r"([A-Za-z_][\w]*)\s*=", block))
    json_keys_ = json_keys(json.load(open(DEFAULTS, encoding="utf-8")), set())

    stale = sorted(json_keys_ - doc_keys)
    extra = sorted(doc_keys - json_keys_)
    if not stale and not extra:
        return 0
    for k in stale:
        print(f"{DOC}: key '{k}' in {DEFAULTS} but not in the settings reference", file=sys.stderr)
    for k in extra:
        print(f"{DOC}: '{k}' in the settings reference but not in {DEFAULTS}", file=sys.stderr)
    print("regenerate docs/legacy (see docs-sync job in .github/workflows/ci.yml)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
