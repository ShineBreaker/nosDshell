#!/usr/bin/env python3
"""Check that every settings key is declared consistently and has a reader.

Two checks, both over the full key paths (e.g. `dock.pluginSpacing`,
`general.keybinds.keyUp`):

1. Declaration sync: Assets/settings-default.json and the JsonAdapter in
   Commons/Settings.qml declare the same set of keys. A key present in only
   one of them means the settings change skipped a step.

2. Readers: every key is referenced somewhere outside its own declaration,
   the migrations, the generated search index and the translations. A key
   with no reference is dead data: either wire it back to the frontend or
   delete it with a migration (AGENTS.md, settings key states).

3. No declared-key fallbacks: `Settings.data.<declared key> ?? <literal>` is
   always wrong — the JsonAdapter supplies the declared default, so the
   fallback is dead code at best and a frozen stale constant at worst (the
   repo had `frameThickness ?? 12` against declared 8). Undeclared reads are
   caught by check 2 instead.

A key counts as referenced when a source file (QML, JS, Python, shell, Rust)
contains one of
  - the dotted tail `<parent>.<key>` or `<parent>?.<key>`
    (Settings.data.dock.mode, "dock.mode");
  - an alias of the parent object followed by the key, e.g.
    `property var cfg: Settings.data.dock` and then `cfg.mode`;
  - dynamic indexing of the parent (`Settings.data.dock[name]`) together with
    the key as a quoted string in the same file.

Usage:
  Scripts/dev/check-settings-keys.py      # exit 1 if any problem is found
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULTS = ROOT / "Assets" / "settings-default.json"
SETTINGS_QML = ROOT / "Commons" / "Settings.qml"

SOURCE_GLOBS = ["**/*.qml", "**/*.js", "**/*.py", "**/*.sh", "tools/*/src/**/*.rs"]
EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "Migrations", "__pycache__"}
EXCLUDED_FILES = {Path("Scripts/dev/check-settings-keys.py")}


def default_paths(obj, prefix=()):
    """Key paths of settings-default.json. Objects nest; arrays and scalars are leaves."""
    paths = []
    for key, value in obj.items():
        path = prefix + (key,)
        if isinstance(value, dict) and value:
            paths.extend(default_paths(value, path))
        else:
            paths.append(path)
    return paths


def strip_strings_and_comments(line):
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line.split("//", 1)[0]


def adapter_paths(text):
    """Key paths declared by the JsonAdapter block of Settings.qml.

    Returns (paths, declaration_lines). declaration_lines are line numbers of
    the property declarations, so the reader check can ignore them.
    """
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if re.match(r"\s*JsonAdapter\s*\{", l))
    paths, decl_lines = [], set()
    depth = 0
    stack = []  # (name, depth inside its braces)
    pending = {}  # JsonObject declared without an inline value: name -> parent path
    for idx in range(start, len(lines)):
        raw = lines[idx]
        code = strip_strings_and_comments(raw)
        prefix = tuple(name for name, _ in stack)
        at_object_level = (stack and depth == stack[-1][1]) or (not stack and depth == 1)
        if at_object_level:
            m = re.match(r"\s*property\s+JsonObject\s+(\w+)\s*(:\s*JsonObject\s*\{)?", code)
            if m:
                decl_lines.add(idx + 1)
                if m.group(2):
                    stack.append((m.group(1), depth + 1))
                else:
                    pending[m.group(1)] = prefix
            else:
                m = re.match(r"\s*(\w+)\s*:\s*JsonObject\s*\{", code)
                if m and m.group(1) in pending:
                    stack.append((m.group(1), depth + 1))
                else:
                    m = re.match(r"\s*(?:readonly\s+)?property\s+[\w<>]+\s+(\w+)", code)
                    if m:
                        decl_lines.add(idx + 1)
                        paths.append(prefix + (m.group(1),))
        for ch in code:
            if ch in "{[":
                depth += 1
            elif ch in "}]":
                depth -= 1
                if stack and depth < stack[-1][1]:
                    stack.pop()
        if depth == 0 and idx > start:
            break
    return [p for p in paths if p != ("settingsVersion",)] + [("settingsVersion",)], decl_lines


def source_files():
    seen = set()
    for pattern in SOURCE_GLOBS:
        for path in ROOT.glob(pattern):
            rel = path.relative_to(ROOT)
            if rel in seen or rel in EXCLUDED_FILES or any(part in EXCLUDED_DIRS for part in rel.parts):
                continue
            seen.add(rel)
            yield rel


def strip_comments(text, suffix):
    """Remove comments but keep string literals (they can carry key names).

    A comment that mentions a key is documentation, not a reader; a string
    literal can be the key used by dynamic indexing (`data.dock["mode"]`).
    """
    if suffix in (".qml", ".js", ".rs"):
        line_c, block = "//", ("/*", "*/")
        quotes = "\"'`"
    elif suffix == ".py":
        line_c, block = "#", None
        quotes = "\"'"
    elif suffix == ".sh":
        line_c, block = "#", None
        quotes = "\"'"
    else:
        return text
    # In shell, # starts a comment only at a word boundary (foo#bar, ${v#p} are code).
    needs_boundary = suffix == ".sh"
    out, i, n = [], 0, len(text)
    in_str = in_line = in_block = False
    while i < n:
        ch = text[i]
        two = text[i : i + 2]
        if in_line:
            if ch == "\n":
                in_line = False
                out.append(ch)
            i += 1
        elif in_block:
            if two == block[1]:
                in_block = False
                i += 2
            else:
                out.append("\n" if ch == "\n" else " ")
                i += 1
        elif in_str:
            out.append(ch)
            if ch == "\\":
                out.append(text[i + 1] if i + 1 < n else "")
                i += 2
            else:
                if ch == in_str:
                    in_str = False
                i += 1
        elif block and two == block[0]:
            in_block = True
            i += 2
        elif line_c and text.startswith(line_c, i) and (
            not needs_boundary or i == 0 or text[i - 1] in " \t\n"
        ):
            in_line = True
            i += len(line_c)
        elif ch in quotes:
            in_str = ch
            out.append(ch)
            i += 1
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def load_corpus(settings_decl_lines):
    corpus = {}
    for rel in source_files():
        text = strip_comments((ROOT / rel).read_text(errors="replace"), rel.suffix)
        if rel == Path("Commons/Settings.qml"):
            text = "\n".join(
                "" if (i + 1) in settings_decl_lines else line for i, line in enumerate(text.splitlines())
            )
        corpus[rel] = text
    return corpus


DOTTED = re.compile(r"\b(\w+)(?=\s*\??\.\s*(\w+))")
ALIAS = re.compile(r"\b(\w+)\s*[:=]\s*(?:Settings\??\.)?data\??\.((?:\w+\??\.)*\w+)\s*(?:;|$|\n|\|\|)", re.M)
DYNAMIC = re.compile(r"\bdata\??\.((?:\w+\??\.)*\w+)\s*\[")
QUOTED = re.compile(r"[\"'](\w+)[\"']")


def index_file(text):
    """Per-file lookup sets, so each key check is a set membership test."""
    pairs = set(DOTTED.findall(text))
    aliases = {}
    for name, target in ALIAS.findall(text):
        aliases.setdefault(target.replace("?", "").split(".")[-1], set()).add(name)
    dynamic = {t.replace("?", "").split(".")[-1] for t in DYNAMIC.findall(text)}
    quoted = set(QUOTED.findall(text))
    return pairs, aliases, dynamic, quoted


def is_referenced(path, indexes):
    key = path[-1]
    parent = path[-2]
    for pairs, aliases, dynamic, quoted in indexes:
        if (parent, key) in pairs:
            return True
        if any((alias, key) in pairs for alias in aliases.get(parent, ())):
            return True
        if parent in dynamic and key in quoted:
            return True
    return False


def declared_version(text):
    """The singleton's settingsVersion (the file's `readonly property int`)."""
    m = re.search(r"readonly\s+property\s+int\s+settingsVersion\s*:\s*(\d+)", text)
    return int(m.group(1)) if m else None


FALLBACK = re.compile(r"\bSettings\s*\??\.\s*data\s*\??\.\s*((?:\w+\s*\??\.\s*)*\w+)\s*\?\?")


def declared_fallbacks(corpus, declared):
    """`Settings.data.<declared key> ?? ...` occurrences, as "rel:line" strings."""
    names = {".".join(path) for path in declared}
    hits = []
    for rel, text in corpus.items():
        for m in FALLBACK.finditer(text):
            path = re.sub(r"[\s?]", "", m.group(1))
            if path in names:
                line = text[: m.start()].count("\n") + 1
                hits.append(f"{rel}:{line}")
    return hits


def main():
    defaults_json = json.loads(DEFAULTS.read_text())
    defaults = set(default_paths(defaults_json))
    settings_text = SETTINGS_QML.read_text()
    declared, decl_lines = adapter_paths(settings_text)
    declared = set(declared)

    problems = 0
    # The defaults file's version is the schema version: it must match the
    # JsonAdapter's target. generateDefaultSettings() only runs when invoked
    # by hand, so a hand-edit can leave this stale (it drifted to 76 while
    # migrations 77-79 moved Settings.qml to 79).
    version = declared_version(settings_text)
    if version is None:
        print("settingsVersion not found in Commons/Settings.qml")
        problems += 1
    elif defaults_json.get("settingsVersion") != version:
        print(f"settingsVersion drift: settings-default.json={defaults_json.get('settingsVersion')} "
              f"Settings.qml={version} — regenerate defaults (Settings.generateDefaultSettings) "
              "or sync the number by hand")
        problems += 1

    for path in sorted(defaults - declared):
        print(f"only in settings-default.json: {'.'.join(path)}")
        problems += 1
    for path in sorted(declared - defaults):
        print(f"only in Commons/Settings.qml: {'.'.join(path)}")
        problems += 1

    corpus = load_corpus(decl_lines)
    indexes = [index_file(text) for text in corpus.values()]
    for path in sorted(defaults | declared):
        if path == ("settingsVersion",):
            continue
        if not is_referenced(path, indexes):
            print(f"no reader: {'.'.join(path)}")
            problems += 1

    # ?? on a declared key is dead code that hides schema drift — and has a
    # history of freezing the wrong constant (frameThickness ?? 12 vs. 8).
    for hit in declared_fallbacks(corpus, declared):
        print(f"?? fallback on declared key: {hit} — the adapter always supplies the declared value")
        problems += 1

    if problems:
        print(f"\n{problems} settings key problem(s). Wire the key to its consumer, or delete it with a migration "
              "(see CODING_STANDARDS.md, 迁移写法).", file=sys.stderr)
        return 1
    print(f"settings keys ok: {len(defaults)} keys declared in both places, all referenced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
