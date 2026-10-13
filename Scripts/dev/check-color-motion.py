#!/usr/bin/env python3
"""Check colour/motion convergence (DESIGN.md §1.7).

a) Every `Behavior on color` / `Behavior on border.color` must animate on a
   motion token (`duration: Style.motion<Name>`) — `Style.animationFast` etc.
   and literal durations don't say *why* the colour moves. Row-class elements
   (menu rows, list/grid delegates, settings rows, navigation buttons, dock
   and tray items, workspace pills) must not carry such Behaviors at all:
   their pointer-state colour snaps (瞬变清单).

b) Every `easing.type:` must come from the §1.7 curve vocabulary:
   OutCubic (enter), InOutCubic (geometry/page), InCubic (fast exit),
   OutQuad (programmatic scroll), OutQuint (wheel inertia), Linear
   (spin/loop/timer/drag-follow).

c) `Behavior on opacity` inside a `delegate:` block or inside the context
   menus flags a hover-revealed row control that should appear instantly —
   but only when the behavior's owner element binds its own `opacity:` to
   hover state; data/lifecycle fades (empty-state, dead-app dim, notification
   in/out) stay legal.

Usage:
  Scripts/dev/check-color-motion.py     # exit 1 if any problem is found
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "__pycache__"}
# Row-internal hover reveals snap (rule c); the two menu widgets get an
# all-file ban because every visible element in them is a row.
CONTEXT_MENU_FILES = {"NContextMenu.qml", "NPopupContextMenu.qml"}

COLOR_BEHAVIOR = re.compile(r"\bBehavior on (?:border\.)?color\s*\{")
OPACITY_BEHAVIOR = re.compile(r"\bBehavior on opacity\s*\{")
DELEGATE_ITEM = re.compile(r"\bdelegate\s*:\s*\w+\s*\{")
HOVER_OPACITY = re.compile(r"\bopacity\s*:\s*[^}\n]*(?:hover|containsMouse|isHovered|hovering)", re.IGNORECASE)
DURATION_PROP = re.compile(r"\bduration\s*:\s*([^}\n]+)")
MOTION_TOKEN = re.compile(r"Style\.motion[A-Z]\w*")
EASING_PROP = re.compile(r"\beasing\.type\s*[:=]\s*Easing\.(\w+)")
ALLOWED_EASINGS = {"OutCubic", "InOutCubic", "InCubic", "OutQuad", "OutQuint", "Linear"}


def strip_code(line):
    """Drop line comments and string literals so `Behavior on color {` can't
    match in prose. Backtick strings are kept: Qt.createQmlObject embeds real
    QML in them."""
    line = line.split("//", 1)[0]
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def block_end(lines, start):
    """Return the exclusive end line of the block whose `{` is on `start`."""
    depth = 0
    for idx in range(start, len(lines)):
        code = strip_code(lines[idx])
        depth += code.count("{") + code.count("[") - code.count("}") - code.count("]")
        if depth <= 0:
            return idx + 1
    return len(lines)


def check_file(path):
    problems = []
    lines = path.read_text(errors="replace").splitlines()
    is_context_menu = path.name in CONTEXT_MENU_FILES

    # (a)+(c): walk behavior declarations and their blocks.
    delegate_depth = None  # brace depth where a `delegate: Item {` opened
    opener = {}  # depth -> line that opened the innermost block at that depth
    depth = 0
    idx = 0
    while idx < len(lines):
        code = strip_code(lines[idx])
        if delegate_depth is not None and depth <= delegate_depth:
            delegate_depth = None
        if COLOR_BEHAVIOR.search(code):
            end = block_end(lines, idx)
            body = "\n".join(strip_code(l) for l in lines[idx:end])
            durations = DURATION_PROP.findall(body)
            if not durations or not any(MOTION_TOKEN.search(d) for d in durations):
                found = durations[0].strip() if durations else "<none>"
                problems.append(f"{path.relative_to(ROOT)}:{idx + 1}: color Behavior without a Style.motion* duration "
                                f"(found `duration: {found}`; DESIGN.md §1.7 wants motionPointer/motionSwitch, "
                                "or no Behavior at all on row-class elements)")
        if OPACITY_BEHAVIOR.search(code) and (is_context_menu or delegate_depth is not None):
            if is_context_menu:
                problems.append(f"{path.relative_to(ROOT)}:{idx + 1}: Behavior on opacity inside a context menu — "
                                "hover-revealed row controls appear instantly (DESIGN.md §1.7 瞬变清单)")
            else:
                # The Behavior animates the enclosing element's opacity — flag
                # it only when *that element's own* opacity is pointer-driven
                # (hover reveal must be instant); lifecycle/data fades and
                # deeper children's hover state stay legal.
                owner = opener.get(depth)
                if owner is not None:
                    end = block_end(lines, owner)
                    lvl = 0
                    for li in range(owner, end):
                        oc = strip_code(lines[li])
                        if lvl == 1 and HOVER_OPACITY.search(oc):
                            problems.append(f"{path.relative_to(ROOT)}:{idx + 1}: Behavior on opacity on a hover-driven "
                                            "element inside a delegate — hover-revealed row controls appear instantly "
                                            "(DESIGN.md §1.7 瞬变清单)")
                            break
                        lvl += oc.count("{") + oc.count("[") - oc.count("}") - oc.count("]")
        opens = code.count("{") + code.count("[")
        closes = code.count("}") + code.count("]")
        if DELEGATE_ITEM.search(code) and delegate_depth is None:
            delegate_depth = depth  # block lives strictly inside this level
        depth += opens - closes
        if opens > closes:
            opener[depth] = idx
        idx += 1

    # (b): easing vocabulary, whole file.
    for idx, raw in enumerate(lines):
        code = strip_code(raw)
        for m in EASING_PROP.finditer(code):
            if m.group(1) not in ALLOWED_EASINGS:
                problems.append(f"{path.relative_to(ROOT)}:{idx + 1}: easing.type Easing.{m.group(1)} not in the §1.7 "
                                "vocabulary (OutCubic/InOutCubic/InCubic/OutQuad/OutQuint/Linear)")
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
        print(f"\n{len(problems)} color/motion violation(s). See DESIGN.md §1.7 "
              "(颜色过渡标注意图, 瞬变清单, 曲线词汇表).", file=sys.stderr)
        return 1
    print("color motion ok: color Behaviors use motion tokens, easings stay in the §1.7 vocabulary")
    return 0


if __name__ == "__main__":
    sys.exit(main())
