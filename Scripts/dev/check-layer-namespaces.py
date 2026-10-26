#!/usr/bin/env python3
"""Check every emitted layer-shell namespace is classified by the canonical
niri rules in Scripts/docs/nosdshell-layer-rules.kdl.

nosDshell namespaces all look like "nosdshell-<stem>-<output>" (a few have
no suffix). The niri layer-rules that decide which surfaces get compositor
blur live outside this repo (the user's niri config), so the canonical copy
here doubles as the vendored wiki content — vendor-legacy-docs.py injects
it into the generated niri page.

Three tiers (see the kdl header): xray=false (real blur for surfaces that
publish ext-background-effect regions and float over windows), xray=true
(cheap wallpaper-sampled blur for static fullscreen surfaces), blur=false
(never). Under niri ≥ 26.04 client blur regions need no rule at all; the
rules only choose the mode or pin "never".

Extraction: every `WlrLayershell.namespace:` binding contributes one sample
name — the first quoted literal, plus a suffix when the expression appends
runtime parts ("-" + screen/edge/windowType). `windowType` is resolved from
the `property string windowType:` default in the same file.

Rules parsing: each `layer-rule { ... }` block contributes its
`match namespace="..."` regexes plus the surface-level `background-effect`
flags (`blur`/`xray`). Flags inside a `popups {}` block apply to popup
surfaces, not the layer surface, and are tracked separately — they do not
classify a namespace.

Checks:
1. `blur true` at surface level — always wrong for nosdshell: most surfaces
   are fullscreen planes, so whole-surface blur covers the screen (the
   2026-10 giant-blur regression). Blur belongs in `popups {}` or comes
   from the client's ext-background-effect regions.
2. A sample matched by no surface-level rule — unclassified namespace.
3. A sample whose rules disagree on the same property — in niri the later
   rule wins, so file order would be load-bearing.
4. An alternation member matched by no sample — stale rule entry.
5. A namespace emitted by a file that also publishes
   `BackgroundEffect.blurRegion` must not resolve to `blur false` — in
   niri that flag force-disables the client's own ext-background-effect
   regions, which was the 2026-10 popupmenu dialog regression
   (translucent mask, sharp backdrop).
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
# A `popups { ... }` block is nested — match through the closing pair of
# braces so the inner background-effect isn't half-stripped.
POPUPS_RE = re.compile(r"popups\s*\{[\s\S]*?\}\s*\}", re.S)
EFFECT_RE = re.compile(r"background-effect\s*\{(.*?)\}", re.S)
FLAG_RE = re.compile(r"(blur|xray)\s+(true|false)")
ALT_RE = re.compile(r"\(([^()]*)\)")


def emitted_samples():
    samples = []  # (sample, file, line_no, publishes_blur_region)
    for qml in sorted(ROOT.rglob("*.qml")):
        if EXCLUDED_DIRS & set(qml.parts):
            continue
        text = qml.read_text()
        publishes = "BackgroundEffect.blurRegion" in text
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
            samples.append((sample, qml.relative_to(ROOT), i, publishes))
    return samples


def effect_flags(effect_body):
    return {k: v == "true" for k, v in FLAG_RE.findall(effect_body)}


def parse_rules():
    """Each rule -> (patterns, surface_flags, popups_flags)."""
    rules = []
    for block in RULE_RE.finditer(RULES_FILE.read_text()):
        body = block.group(1)
        patterns = MATCH_RE.findall(body)
        popups_flags = {}
        for pb in POPUPS_RE.finditer(body):
            eff = EFFECT_RE.search(pb.group(0))
            if eff:
                popups_flags.update(effect_flags(eff.group(1)))
        surface_body = POPUPS_RE.sub("", body)
        surface_flags = {}
        eff = EFFECT_RE.search(surface_body)
        if eff:
            surface_flags = effect_flags(eff.group(1))
        if patterns:
            rules.append((patterns, surface_flags, popups_flags))
    return rules


def main():
    fail = 0
    samples = emitted_samples()
    raw_rules = parse_rules()
    rules = [([re.compile(r) for r in ps], ps, sf, pf)
             for ps, sf, pf in raw_rules]

    # Guard 1: surface-level `blur true` is never correct here.
    for _, raw_ps, sf, _ in rules:
        if sf.get("blur") is True:
            print(f"SURFACE-BLUR {raw_ps}: `blur true` on a layer surface blurs"
                  " its whole extent — put it in popups {{}} or publish an"
                  " ext-background-effect region instead")
            fail = 1

    classified = {}  # sample -> {prop: bool}
    for sample, path, line, publishes in samples:
        props = {}
        for compiled, _, sf, _ in rules:
            if not sf or not any(r.search(sample) for r in compiled):
                continue
            for k, v in sf.items():
                if k in props and props[k] != v:
                    print(f"CONFLICT {path}:{line} {sample!r}: `{k}` set to"
                          f" {props[k]} and {v} by different rules")
                    fail = 1
                props[k] = v
        if not props:
            print(f"UNCLASSIFIED {path}:{line} {sample!r} matches no"
                  " surface-level rule")
            fail = 1
        else:
            classified[sample] = props
            if publishes and props.get("blur") is False:
                print(f"BLUR-DENIED {path}:{line} {sample!r}: file publishes"
                      " BackgroundEffect.blurRegion but the matching rule"
                      " pins `blur false`, which force-disables client"
                      " regions — move it to the xray tiers")
                fail = 1

    # Reverse: every alternation member should still correspond to a real
    # emitted namespace, so the file cannot silently rot.
    for _, raw_ps, _, _ in rules:
        for rs in raw_ps:
            stem = ALT_RE.search(rs)
            if not stem:
                continue
            for alt in stem.group(1).split("|"):
                member_pat = re.compile(rs.replace(f"({stem.group(1)})", re.escape(alt)))
                if not any(member_pat.search(s) for s in classified):
                    print(f"STALE member {alt!r} in {rs!r}: no emitted namespace matches")
                    fail = 1

    if not fail:
        print(f"ok: {len(samples)} namespace binding(s),"
              f" {sum(len(r[1]) for r in rules)} rule pattern(s)")
    sys.exit(fail)


if __name__ == "__main__":
    main()
