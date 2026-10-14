#!/usr/bin/env python3
"""Require an explicit accepted assignment in every wheel-event onWheel.

Under niri a wheel event arrives already accepted: a MouseArea/WheelHandler
onWheel that neither sets `wheel.accepted = false` before returning (to pass
the event to what is underneath) nor `wheel.accepted = true` (to consume it
on purpose) silently swallows the event on niri while sway lets it pass —
the divergence only shows on niri. CODING_STANDARDS.md "QML 规则" (wheel
条) mandates the explicit assignment; this check fails on any wheel-event
onWheel handler whose body carries no `<name>.accepted =` assignment at all,
so the next omission is caught at lint time. Compliant shapes to copy:
Widgets/NScrollView.qml's wheel overlay, SettingsModuleView's takeover
layer, Cards/AudioCard.qml.

A handler only counts when its owning object is a MouseArea or a
WheelHandler: `onWheel:` also names the handler of the custom
`signal wheel(int delta)` that BarPill (and friends) re-emit, whose argument
is a plain number with no accepted field — the event's fate is decided at
the forwarding MouseArea, not in the signal handler. Custom components whose
root were a MouseArea would defeat this attribution, but the repo has none.

Usage:
  Scripts/dev/check-wheel-accepted.py [paths...]   # exit 1 on any hit
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ON_WHEEL = re.compile(r"\bonWheel\s*:")
ASSIGN = re.compile(r"\b\w+\.accepted\s*=")
# handler-parameter prefix between `onWheel:` and the body:
# `wheel =>`, `function (event)` or `function(event)`
LAMBDA = re.compile(r"\s*(?:function\s*\([^)]*\)|(?:[A-Za-z_$][\w$]*\s*)?=>)\s*")
# a `{` opens a QML object declaration when the word before it is a type
# name; a JS block when it follows `:` (binding), `=>` or `)` (function)
WORD_BEFORE_BRACE = re.compile(r"([A-Za-z_$][\w$]*)\s*$")
WHEEL_EVENT_OWNERS = {"MouseArea", "WheelHandler"}


def skip_string(text, i):
    """i points at the opening quote; return the index just past the close."""
    quote = text[i]
    i += 1
    while i < len(text):
        c = text[i]
        if c == "\\":
            i += 2
            continue
        if c == quote:
            return i + 1
        i += 1
    return i


def skip_comment(text, i):
    """i points at the first '/'; return the index just past the comment."""
    if text[i + 1:i + 2] == "/":
        end = text.find("\n", i)
        return len(text) if end == -1 else end
    end = text.find("*/", i + 2)
    return len(text) if end == -1 else end + 2


def scan(text, on_wheel_hits):
    """One pass over the file: track the owning object of every `onWheel:`.

    `stack` holds one entry per open `{`: a type name for QML object
    declarations, None for JS blocks (binding bodies, lambdas, functions).
    `on_wheel_hits` receives (position, owned_by_wheel_event_type).
    """
    stack = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c in "\"'":
            i = skip_string(text, i)
            continue
        if c == "/" and text[i + 1:i + 2] in "/*":
            i = skip_comment(text, i)
            continue
        if c == "{":
            before = text[:i].rstrip()
            m = WORD_BEFORE_BRACE.search(before)
            stack.append(m.group(1) if m else None)
            i += 1
            continue
        if c == "}":
            if stack:
                stack.pop()
            i += 1
            continue
        m = ON_WHEEL.match(text, i)
        if m:
            owner = next((t for t in reversed(stack) if t is not None), None)
            on_wheel_hits.append((m.start(), owner in WHEEL_EVENT_OWNERS))
            i = m.end()
            continue
        i += 1


def handler_body(text, colon_end):
    """Return the handler body after `onWheel:`.

    Accepts `name => { ... }` / `function (x) { ... }` blocks (brace-
    balanced, skipping strings and comments) and single-expression bodies
    (to end of line)."""
    m = LAMBDA.match(text, colon_end)
    start = m.end() if m else colon_end
    while start < len(text) and text[start] in " \t":
        start += 1
    if start < len(text) and text[start] == "{":
        depth = 1
        j = start + 1
        while j < len(text) and depth > 0:
            c = text[j]
            if c in "\"'":
                j = skip_string(text, j)
                continue
            if c == "/" and text[j + 1:j + 2] in "/*":
                j = skip_comment(text, j)
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            j += 1
        return text[start:j]
    eol = text.find("\n", start)
    return text[start:len(text) if eol == -1 else eol]


def check_file(path):
    try:
        rel = path.relative_to(ROOT)
    except ValueError:
        rel = path
    hits = []
    text = path.read_text(errors="replace")
    found = []
    scan(text, found)
    for pos, is_wheel_event in found:
        if not is_wheel_event:
            continue
        body = handler_body(text, text.index(":", pos) + 1)
        if not ASSIGN.search(body):
            line = text.count("\n", 0, pos) + 1
            hits.append(f"{rel}:{line}")
    return hits


def main():
    if len(sys.argv) > 1:
        files = [Path(a).resolve() for a in sys.argv[1:]]
    else:
        files = [
            p for p in ROOT.rglob("*.qml")
            if not any(part in {"references", ".git"} for part in p.relative_to(ROOT).parts)
        ]
    hits = []
    for path in files:
        if path.is_file():
            hits.extend(check_file(path))
    if hits:
        for h in hits:
            print(f"onWheel without an accepted assignment: {h} — set "
                  "<event>.accepted = false before an early return, "
                  "<event>.accepted = true to consume (CODING_STANDARDS \"QML 规则\")")
        return 1
    print(f"wheel accepted ok: every wheel-event onWheel handler assigns "
          f"accepted ({len(files)} files scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
