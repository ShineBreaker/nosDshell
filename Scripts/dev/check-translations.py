#!/usr/bin/env python3
"""Check that translation keys and the code that uses them agree.

Assets/Translations/en.json is the reference: every other language file is a
subset of it, and English is the runtime fallback (Commons/I18n.qml).

Checks:
1. Missing: every literal key passed to I18n.tr() / I18n.trp() exists in
   en.json (trp also needs `<key>-plural`). A missing key renders as
   `!!key!!` in the interface.
2. Unreferenced: every en.json key is used by the code. A key counts as used
   when its full dotted name appears as a string literal in any QML/JS/Python
   source or Assets JSON file, when it starts with a prefix the code builds
   dynamically (`"panels.osd." + name`, `` `wallpaper.transitions.${x}` ``),
   or when it is the `-plural` form of a used key.
3. Orphans: no other language file has keys that en.json lacks.
4. zh-CN.json carries every en.json key (CODING_STANDARDS.md, 界面文字).
5. zh-CN.json values hold no untranslated interface terms (DESIGN.md
   §1.10): the BANNED English words below must not appear. ALLOWED
   originals (abbreviations, product names, command names) are masked
   before matching, and hook/placeholder/debug keys that quote command
   originals are exempt. --fix never touches these; translate by hand.

Usage:
  Scripts/dev/check-translations.py          # report, exit 1 on any problem
  Scripts/dev/check-translations.py --fix    # delete unreferenced keys from
                                             # every language file and orphan
                                             # keys from the translations
                                             # (check 5 is only reported)
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TRANSLATIONS = ROOT / "Assets" / "Translations"
REFERENCE = TRANSLATIONS / "en.json"
REQUIRED_COMPLETE = ["zh-CN.json"]

EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "__pycache__", "Translations"}
EXCLUDED_FILES = {Path("Scripts/dev/check-translations.py")}

# Check 5 (DESIGN.md §1.10): interface Chinese uses the DDE term, never the
# English word from the left column of the §1.10 table. OSD is not banned:
# it is a retainable abbreviation (see ALLOWED_TOKENS). Matching is
# case-sensitive with ASCII word boundaries, so CJK text next to a term
# ("Dock栏") still matches while "Widgets" does not.
BANNED_TERMS = [
    "Dock", "Bar", "Workspace", "Launcher", "Bluetooth", "Toast",
    "Widget", "widget", "Session", "Control Center", "Notification Center",
    "Compositor", "Tooltip", "Faithful",
]
BANNED_TERM = re.compile(r"\b(" + "|".join(map(re.escape, BANNED_TERMS)) + r")\b", re.ASCII)

# Retainable originals (DESIGN.md §1.10): masked before matching so they
# can never flag, e.g. the CPU in "标有 ! 的 Widget 会占用更多 CPU".
ALLOWED_TOKENS = [
    "Wi-Fi", "VPN", "CPU", "GPU", "OSD", "IPC", "JSON", "UEFI", "Markdown",
    "nosDshell", "niri", "Wallhaven", "GitHub", "Material",
]

# Keys quoting command originals, not interface prose (DESIGN.md §1.10).
EXEMPT_KEY = re.compile(r"^placeholders\." r"|^panels\.hooks\." r"|-placeholder$" r"|^debug\.")

LITERAL = re.compile(r'"((?:\\.|[^"\\\n])*)"|\'((?:\\.|[^\'\\\n])*)\'|`([^`]*)`')
CONCAT_PREFIX = re.compile(r'["\']([\w.-]+[.-])["\']\s*\+')
TR_CALL = re.compile(r'I18n\??\.(trp?)\(\s*["\']([^"\'\n]+)["\']\s*[,)]')


def leaves(obj, prefix=()):
    for key, value in obj.items():
        path = prefix + (key,)
        if isinstance(value, dict):
            yield from leaves(value, path)
        else:
            yield ".".join(path)


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def delete_key(data, dotted):
    parts = dotted.split(".")
    chain = [data]
    for part in parts[:-1]:
        node = chain[-1].get(part)
        if not isinstance(node, dict):
            return False
        chain.append(node)
    if parts[-1] not in chain[-1]:
        return False
    del chain[-1][parts[-1]]
    for depth in range(len(chain) - 1, 0, -1):
        if not chain[depth]:
            del chain[depth - 1][parts[depth - 1]]
    return True


def untranslated_terms(data):
    """Yield (key, value, term) for zh-CN values holding a BANNED term."""
    found = []

    def walk(obj, prefix=()):
        for key, value in obj.items():
            path = prefix + (key,)
            if isinstance(value, dict):
                walk(value, path)
            elif isinstance(value, str):
                dotted = ".".join(path)
                if EXEMPT_KEY.search(dotted):
                    continue
                # {name} is a format placeholder, not the word itself
                masked = re.sub(r"\{[^}]*\}", "", value)
                for token in ALLOWED_TOKENS:
                    masked = masked.replace(token, "")
                m = BANNED_TERM.search(masked)
                if m:
                    found.append((dotted, value, m.group(1)))

    walk(data)
    return found


def source_files():
    patterns = ["**/*.qml", "**/*.js", "**/*.py", "**/*.sh", "tools/*/src/**/*.rs", "Assets/**/*.json"]
    seen = set()
    for pattern in patterns:
        for path in ROOT.glob(pattern):
            rel = path.relative_to(ROOT)
            if rel in seen or rel in EXCLUDED_FILES or any(part in EXCLUDED_DIRS for part in rel.parts):
                continue
            seen.add(rel)
            yield rel


def scan_sources():
    literals, prefixes, calls = set(), set(), []
    for rel in source_files():
        text = (ROOT / rel).read_text(errors="replace")
        for m in LITERAL.finditer(text):
            if m.group(3) is not None and "${" in m.group(3):
                prefixes.add(m.group(3).split("${", 1)[0])
            else:
                literals.add(m.group(1) or m.group(2) or m.group(3) or "")
        prefixes.update(CONCAT_PREFIX.findall(text))
        if rel.suffix in (".qml", ".js"):
            for m in TR_CALL.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                calls.append((rel, line, m.group(1), m.group(2)))
    # Short fragments ("-", "a.") are concatenation noise, not key prefixes.
    prefixes = {p for p in prefixes if len(p.rstrip(".-")) >= 3}
    return literals, prefixes, calls


def main():
    fix = "--fix" in sys.argv[1:]
    reference = load(REFERENCE)
    ref_keys = list(leaves(reference))
    ref_set = set(ref_keys)
    literals, prefixes, calls = scan_sources()
    problems = 0

    for rel, line, fn, key in calls:
        needed = [key] if fn == "tr" else [key, key + "-plural"]
        for k in needed:
            if k not in ref_set:
                print(f"missing in en.json: {k}  ({rel}:{line})")
                problems += 1

    def used(key):
        if key in literals or any(key.startswith(p) for p in prefixes):
            return True
        return key.endswith("-plural") and used(key[: -len("-plural")])

    unreferenced = [k for k in ref_keys if not used(k)]

    orphans = {}
    incomplete = {}
    for path in sorted(TRANSLATIONS.glob("*.json")):
        if path == REFERENCE:
            continue
        keys = set(leaves(load(path)))
        extra = sorted(keys - ref_set)
        if extra:
            orphans[path] = extra
        if path.name in REQUIRED_COMPLETE:
            missing = sorted(ref_set - set(unreferenced) - keys)
            if missing:
                incomplete[path] = missing

    if fix:
        removed = 0
        for path in sorted(TRANSLATIONS.glob("*.json")):
            data = load(path)
            doomed = unreferenced + orphans.get(path, [])
            removed += sum(delete_key(data, k) for k in doomed)
            save(path, data)
        print(f"removed {len(unreferenced)} unreferenced key(s) and the orphans, {removed} entries across all languages")
        unreferenced, orphans = [], {}

    for k in unreferenced:
        print(f"unreferenced: {k}")
        problems += 1
    for path, keys in orphans.items():
        for k in keys:
            print(f"orphan in {path.name}: {k}")
            problems += 1
    for path, keys in incomplete.items():
        for k in keys:
            print(f"missing in {path.name}: {k}")
            problems += 1
    for k, v, term in untranslated_terms(load(TRANSLATIONS / "zh-CN.json")):
        print(f"untranslated term in zh-CN.json: {k}: {v}  (matched: {term})")
        problems += 1

    if problems:
        print(f"\n{problems} translation problem(s). Add missing keys to en.json and zh-CN.json; "
              "run with --fix to delete unreferenced and orphan keys; "
              "translate untranslated terms by hand (--fix never touches them).", file=sys.stderr)
        return 1
    print(f"translations ok: {len(ref_set)} keys in en.json, all referenced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
