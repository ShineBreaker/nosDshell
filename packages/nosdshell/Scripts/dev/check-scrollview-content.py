#!/usr/bin/env python3
"""Require an explicit content size on scroll views with several content children.

ScrollView (and NScrollView, which extends it) works out contentWidth and
contentHeight on its own only when it holds exactly one content item: it
reads that item's implicit size. With two or more (a content column plus a
wheel overlay, say) the inferred size is unreliable; the settings module
view's scroll read contentHeight 0 after some open/close sequences, which
silently disabled scrolling and the edge fade. CODING_STANDARDS.md
"QML 规则" (ScrollView 条) asks for an explicit `contentHeight:` in that
case; this check fails on any such declaration without one, so the next one
is caught at lint time. Compliant shape to copy: the settingsContentScroll
NScrollView in Modules/Panels/ControlCenter/SettingsModuleView.qml.

Only direct object children count. Values of a property (`background:
Item {`), `Behavior on x {` and non-visual types (Connections, Timer,
animations, ...) are not content.

Usage:
  Scripts/dev/check-scrollview-content.py [paths...]   # exit 1 on any hit
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCROLL_VIEW = re.compile(r"\b(?:NScrollView|ScrollView)\s*\{")
TYPE_BEFORE_BRACE = re.compile(r"([A-Z][\w.]*)\s*$")
CONTENT_HEIGHT = re.compile(r"^\s*contentHeight\s*:", re.M)
NON_VISUAL = {
    "Connections", "Binding", "Timer", "Component", "QtObject", "Instantiator",
    "Shortcut", "NAnim", "NColorAnim", "NumberAnimation", "ColorAnimation",
    "PropertyAnimation", "SequentialAnimation", "ParallelAnimation",
    "PauseAnimation", "ScriptAction", "PropertyAction", "SmoothedAnimation",
}


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
        return len(text) if end < 0 else end
    end = text.find("*/", i + 2)
    return len(text) if end < 0 else end + 2


def body_children(text, start):
    """start is just past the view's '{'. Return (end, body, child types)."""
    depth = 1
    i = start
    children = []
    while i < len(text) and depth > 0:
        c = text[i]
        if c in "\"'`":
            i = skip_string(text, i)
            continue
        if c == "/" and text[i + 1:i + 2] in ("/", "*"):
            i = skip_comment(text, i)
            continue
        if c == "{":
            if depth == 1:
                line = text[text.rfind("\n", 0, i) + 1:i]
                m = TYPE_BEFORE_BRACE.search(line)
                head = line[:m.start()] if m else ""
                # `prop: Type {` is a property value; `Behavior on x {` is
                # caught by the lowercase word before the brace (no match).
                if m and ":" not in head and not head.strip().endswith(" on"):
                    children.append(m.group(1))
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return i, text[start:i - 1], children


def check(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    hits = []
    for m in SCROLL_VIEW.finditer(text):
        _, body, children = body_children(text, m.end())
        content = [c for c in children if c.split(".")[-1] not in NON_VISUAL]
        if len(content) > 1 and not CONTENT_HEIGHT.search(body):
            line = text.count("\n", 0, m.start()) + 1
            name = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
            hits.append(f"{name}:{line}: scroll view with "
                        f"{len(content)} content children ({', '.join(content)}) "
                        f"sets no contentHeight")
    return hits


def main(argv):
    paths = [Path(p).resolve() for p in argv] if argv else [
        p for d in ("Modules", "Widgets", "Commons", "Services")
        for p in (ROOT / d).rglob("*.qml")
    ]
    hits = [h for p in paths if p.suffix == ".qml" for h in check(p)]
    for h in hits:
        print(h)
    if hits:
        print("scrollview content FAIL: set contentWidth/contentHeight explicitly "
              "(CODING_STANDARDS.md「QML 规则」)")
        return 1
    print(f"scrollview content ok: every scroll view with several content children "
          f"sizes its content ({len(paths)} files scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
