#!/usr/bin/env python3
"""Check that every QtQuick.Controls Popup animates its show/hide.

Popup-type surfaces enter and leave through the shared NPopupEnter /
NPopupExit transitions (DESIGN.md §1.7 motionDialogIn/motionDialogOut). A bare `Popup {` without enter:/exit:
transitions is the exact shape that used to snap open and shut; scan the
whole corpus so the next menu or dialog can't regress it silently.

The scan looks for `Popup {` (also `popup: Popup {` and the Popup
subclasses Menu/Dialog/Drawer) and requires `enter:` and `exit:` inside
the same block (brace-depth scan; `enter:` is only checked at the block's
first level so nested objects can't satisfy it accidentally).

Usage:
  Scripts/dev/check-popup-motion.py     # exit 1 if any problem is found
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "__pycache__"}

POPUP_DECL = re.compile(r"(?<![\w.])(Popup|Menu|Dialog|Drawer)\s*\{")
TRANSITION_PROP = re.compile(r"^\s*(enter|exit)\s*:")
INLINE_TRANSITION = re.compile(r"(?:^|[{\s;])(enter|exit)\s*:")


def strip_code(line):
    """Drop line comments and string literals so `Popup {` can't match in prose."""
    line = line.split("//", 1)[0]
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def popup_blocks(lines):
    """Yield (start_line, end_line_exclusive) for each Popup-like block.

    Each block tracks its own brace depth, so `popup: Popup {` nested
    inside another object — or a Popup inside a Popup — is found too.
    """
    stack = []  # [start_line, block_depth]
    for idx, raw in enumerate(lines):
        code = strip_code(raw)
        if POPUP_DECL.search(code):
            stack.append([idx, 0])
        delta = code.count("{") + code.count("[") - code.count("}") - code.count("]")
        for block in stack:
            block[1] += delta
        while stack and stack[-1][1] <= 0:
            yield stack[-1][0], idx + 1
            stack.pop()


def check_file(path):
    problems = []
    lines = path.read_text(errors="replace").splitlines()
    for start, end in popup_blocks(lines):
        depth = 0
        have_enter = have_exit = False
        for idx in range(start, end):
            code = strip_code(lines[idx])
            found = []
            if idx == start:
                # Properties on the declaration line itself
                # (`Popup { enter: ... }` one-liners).
                found = [m.group(1) for m in INLINE_TRANSITION.finditer(code)]
            elif depth == 1:
                m = TRANSITION_PROP.match(code)
                if m:
                    found = [m.group(1)]
            for which in found:
                shared = "NPopupEnter" if which == "enter" else "NPopupExit"
                if shared not in code:
                    problems.append(f"{path.relative_to(ROOT)}:{idx + 1}: Popup {which}: is not {shared} "
                                    f"(DESIGN §1.7 motionDialogIn/Out — one shared recipe)")
                if which == "enter":
                    have_enter = True
                else:
                    have_exit = True
            depth += code.count("{") + code.count("[") - code.count("}") - code.count("]")
        missing = []
        if not have_enter:
            missing.append("enter:")
        if not have_exit:
            missing.append("exit:")
        if missing:
            problems.append(f"{path.relative_to(ROOT)}:{start + 1}: Popup without {' and '.join(missing)} transition")
    return problems


def main():
    problems = []
    for path in sorted(ROOT.rglob("*.qml")):
        rel = path.relative_to(ROOT)
        if any(part in EXCLUDED_DIRS for part in rel.parts):
            continue
        problems.extend(check_file(path))

    if problems:
        for p in problems:
            print(p)
        print(f"\n{len(problems)} Popup(s) without motion transitions. Add `enter: NPopupEnter {{}}` and "
              "`exit: NPopupExit {}` (DESIGN.md §1.7).", file=sys.stderr)
        return 1
    print("popup motion ok: every QtQuick.Controls Popup declares enter/exit transitions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
