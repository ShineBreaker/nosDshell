#!/usr/bin/env python3
"""Check every emitted layer-shell namespace is classified by the canonical
niri rules in Scripts/docs/nosdshell-layer-rules.kdl.

nosDshell namespaces all look like "nosdshell-<stem>-<output>" (a few have
no suffix). The niri layer-rules that decide which surfaces get compositor
blur live outside this repo (the user's niri config), so the canonical copy
here doubles as the vendored wiki content — vendor-legacy-docs.py injects
it into the generated niri page. When a new surface lands without updating
the rules, niri silently applies no blur (enable-list miss) or stale rule
members linger (disable-list miss); this check turns both into errors.

Extraction: every `WlrLayershell.namespace:` binding contributes one sample
name — the first quoted literal, plus a suffix when the expression appends
runtime parts ("-" + screen/edge/windowType). `windowType` is resolved from
the `property string windowType:` default in the same file.

Rules parsing: each `layer-rule { ... }` block in the kdl file contributes
its `match namespace="..."` regexes plus the block's `blur` bool. Matching
uses `re.search`, same unanchored semantics as niri's regex engine.

Flags:
1. A sample matched by no rule — unclassified namespace.
2. A sample matched by both a blur=true and a blur=false rule — conflict;
   in niri the later rule wins, so the file order is load-bearing.
3. An alternation member matched by no sample — stale rule entry.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
RULES_FILE = ROOT / "Scripts/docs/nosdshell-layer-rules.kdl"
EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "__pycache__"}

NS_RE = re.compile(r"WlrLayershell\.namespace:\s*(.+)")
STRING_RE = re.compile(r'"([^"]*)"')
WINTYPE_RE = re.compile(r'property\s+string\s+windowType:\s*"([^"]*)"')
RULE_RE = re.compile(r"layer-rule\s*\{(.*?)\n\}", re.S)
MATCH_RE = re.compile(r'match\s+namespace="([^"]*)"')
BLUR_RE = re.compile(r"background-effect\s*\{[^}]*?blur\s+(true|false)", re.S)
ALT_RE = re.compile(r"\(([^()]*)\)")


def emitted_samples():
    samples = []  # (sample, file, line_no)
    for qml in sorted(ROOT.rglob("*.qml")):
        if EXCLUDED_DIRS & set(qml.parts):
            continue
        text = qml.read_text()
        wintype = WINTYPE_RE.search(text)
        for i, line in enumerate(text.splitlines(), 1):
            m = NS_RE.search(line)
            if not m:
                continue
            expr = m.group(1)
            lits = STRING_RE.findall(expr)
            if not lits:
                print(f"  {qml.relative_to(ROOT)}:{i}: namespace has no literal: {expr.strip()}")
                continue
            if "windowType" in expr:
                wt = wintype.group(1) if wintype else "<windowType?>"
                sample = lits[0] + wt + "-SAMPLE"
            elif "+" in expr:
                sample = lits[0] + "SAMPLE"
            else:
                sample = lits[0]
            samples.append((sample, qml.relative_to(ROOT), i))
    return samples


def parse_rules():
    rules = []  # (blur_bool, [regex_str, ...])
    for block in RULE_RE.finditer(RULES_FILE.read_text()):
        body = block.group(1)
        regexes = MATCH_RE.findall(body)
        blur = BLUR_RE.search(body)
        if regexes and blur:
            rules.append((blur.group(1) == "true", regexes))
    return rules


def main():
    fail = 0
    samples = emitted_samples()
    rules = [(on, [re.compile(r) for r in rs], rs)
             for on, rs in parse_rules()]

    seen = {}  # sample -> want_blur (for the reverse check below)
    for sample, path, line in samples:
        hits = [on for on, compiled, _ in rules
                if any(r.search(sample) for r in compiled)]
        if len(set(hits)) > 1:
            print(f"CONFLICT {path}:{line} {sample!r} matches blur=true and blur=false rules")
            fail = 1
        elif not hits:
            print(f"UNCLASSIFIED {path}:{line} {sample!r} matches no layer-rule")
            fail = 1
        else:
            seen[sample] = hits[0]

    # Reverse: every alternation member should still correspond to a real
    # emitted namespace, so the file cannot silently rot.
    for on, _, raw in rules:
        for rs in raw:
            stem = ALT_RE.search(rs)
            if not stem:
                continue
            for alt in stem.group(1).split("|"):
                member_pat = re.compile(rs.replace(f"({stem.group(1)})", re.escape(alt)))
                if not any(member_pat.search(s) for s in seen):
                    print(f"STALE {'blur' if on else 'no-blur'} member {alt!r} in {rs!r}: no emitted namespace matches")
                    fail = 1

    if not fail:
        print(f"ok: {len(samples)} namespace binding(s), {sum(len(r[1]) for r in rules)} rule pattern(s)")
    sys.exit(fail)


if __name__ == "__main__":
    main()
