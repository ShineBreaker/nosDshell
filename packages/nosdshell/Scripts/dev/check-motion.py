#!/usr/bin/env python3
"""Check that every animation stays on the DESIGN.md §1.7 motion system.

a) Curves come from the curve table only. Animations are written as NAnim /
   NColorAnim (Widgets/) with a `curve:` name from Style.curves; the raw
   NumberAnimation / ColorAnimation / PropertyAnimation / SmoothedAnimation /
   SpringAnimation types and any `easing.type` other than Easing.Linear are
   rejected outside the primitives themselves (PRIMITIVES).

b) Durations are tokens. `duration:` must not start with a number literal:
   a literal hides which §1.7 scene the motion belongs to and escapes
   general.animationSpeed / reduceMotion. (Timer `interval:` values are
   delays, not animations, and are not checked.)

c) Every `curve:` name an NAnim / NColorAnim uses exists in Style.curves.

d) Colour transitions say why they move: every `Behavior on <...>color`
   (color, border.color, fillColor, borderColor, ...) animates with an
   NColorAnim whose duration is a Style.motion* token (motionPointer for
   pointer feedback, motionSwitch for state colours).

e) Decorative loops honour reduced motion: an animation with
   `loops: Animation.Infinite` must mention Style.reduceMotion in its own
   block or an enclosing block (typically `running: ... && !Style.reduceMotion`).

f) `Behavior on opacity` on a hover-driven element inside a `delegate:` or
   anywhere in the context menus: hover-revealed row controls appear
   instantly (§1.7 瞬变清单).

Usage:
  Scripts/dev/check-motion.py     # exit 1 if any problem is found
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "__pycache__"}
# The primitives own the raw types; Colors.qml drives the theme crossfade on
# Style.curveSwift directly because Commons cannot import Widgets.
PRIMITIVES = {"Widgets/NAnim.qml", "Widgets/NColorAnim.qml", "Commons/Colors.qml"}
CONTEXT_MENU_FILES = {"NContextMenu.qml", "NPopupContextMenu.qml"}

RAW_ANIM = re.compile(r"\b(NumberAnimation|ColorAnimation|PropertyAnimation|SmoothedAnimation|SpringAnimation)\s*(?:on\s+[\w.]+\s*)?\{")
EASING_PROP = re.compile(r"\beasing\.type\s*[:=]\s*Easing\.(\w+)")
BEZIER_PROP = re.compile(r"\beasing\.bezierCurve\s*[:=]")
DURATION_LITERAL = re.compile(r"(?:^|[{;])\s*duration\s*:\s*\d")
CURVE_NAME = re.compile(r"(?:^|[{;])\s*curve\s*:\s*\"(\w+)\"")
COLOR_BEHAVIOR = re.compile(r"\bBehavior on (?:\w+\.)?\w*[cC]olor\s*\{")
OPACITY_BEHAVIOR = re.compile(r"\bBehavior on opacity\s*\{")
DELEGATE_ITEM = re.compile(r"\bdelegate\s*:\s*\w+\s*\{")
HOVER_OPACITY = re.compile(r"\bopacity\s*:\s*[^}\n]*(?:hover|containsMouse|isHovered|hovering)", re.IGNORECASE)
DURATION_PROP = re.compile(r"\bduration\s*:\s*([^}\n]+)")
MOTION_TOKEN = re.compile(r"Style\.motion[A-Z]\w*")
INFINITE = re.compile(r"\bloops\s*:\s*Animation\.Infinite")


def strip_code(line):
    """Drop line comments and string literals (curve names are read from the
    raw line). Backtick strings are kept: Qt.createQmlObject embeds QML."""
    line = line.split("//", 1)[0]
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def block_end(lines, start):
    depth = 0
    for idx in range(start, len(lines)):
        code = strip_code(lines[idx])
        depth += code.count("{") + code.count("[") - code.count("}") - code.count("]")
        if depth <= 0:
            return idx + 1
    return len(lines)


def style_curves():
    text = (ROOT / "Commons" / "Style.qml").read_text()
    m = re.search(r"readonly property var curves:\s*\(\{(.*?)\}\)", text, re.S)
    return set(re.findall(r"\"?(\w+)\"?\s*:", m.group(1))) if m else set()


def check_file(path, curves):
    problems = []
    rel = path.relative_to(ROOT).as_posix()
    lines = path.read_text(errors="replace").splitlines()
    primitive = rel in PRIMITIVES
    is_context_menu = path.name in CONTEXT_MENU_FILES

    def report(idx, msg):
        problems.append(f"{rel}:{idx + 1}: {msg}")

    opener = {}  # depth -> line that opened the innermost block at that depth
    stack = []   # open block start lines, innermost last
    delegate_depth = None
    depth = 0
    for idx, raw in enumerate(lines):
        code = strip_code(raw)
        if delegate_depth is not None and depth <= delegate_depth:
            delegate_depth = None

        if not primitive:
            m = RAW_ANIM.search(code)
            if m:
                report(idx, f"raw {m.group(1)} — use NAnim / NColorAnim with a §1.7 curve name")
            for e in EASING_PROP.finditer(code):
                if e.group(1) != "Linear":
                    report(idx, f"easing.type Easing.{e.group(1)} — curves come from Style.curves via NAnim `curve:` (§1.7)")
            if BEZIER_PROP.search(code):
                report(idx, "hand-written easing.bezierCurve — add the curve to the §1.7 table instead")
        if DURATION_LITERAL.search(code):
            report(idx, "literal animation duration — use a Style.motion*/dur* token (§1.7)")
        for c in CURVE_NAME.finditer(raw.split("//", 1)[0]):
            if c.group(1) != "linear" and c.group(1) not in curves:
                report(idx, f"unknown curve \"{c.group(1)}\" (Style.curves: {', '.join(sorted(curves))})")

        if COLOR_BEHAVIOR.search(code):
            end = block_end(lines, idx)
            body = "\n".join(strip_code(l) for l in lines[idx:end])
            durations = DURATION_PROP.findall(body)
            if "NColorAnim" not in body and not primitive:
                report(idx, "colour Behavior without NColorAnim (§1.7 颜色过渡标注意图)")
            if not durations or not any(MOTION_TOKEN.search(d) for d in durations):
                found = durations[0].strip() if durations else "<none>"
                report(idx, f"colour Behavior without a Style.motion* duration (found `duration: {found}`; "
                            "motionPointer for pointer feedback, motionSwitch for state colours, "
                            "or no Behavior at all on row-class elements)")

        if INFINITE.search(code):
            chain = stack[-3:] + [idx]
            text = "\n".join("\n".join(lines[s:block_end(lines, s)]) for s in chain)
            if "reduceMotion" not in text:
                report(idx, "infinite loop ignores Style.reduceMotion — gate `running` on it (§1.7 减弱动效)")

        if OPACITY_BEHAVIOR.search(code) and (is_context_menu or delegate_depth is not None):
            if is_context_menu:
                report(idx, "Behavior on opacity inside a context menu — hover-revealed row controls appear "
                            "instantly (§1.7 瞬变清单)")
            else:
                owner = opener.get(depth)
                if owner is not None:
                    end = block_end(lines, owner)
                    lvl = 0
                    for li in range(owner, end):
                        oc = strip_code(lines[li])
                        if lvl == 1 and HOVER_OPACITY.search(oc):
                            report(idx, "Behavior on opacity on a hover-driven element inside a delegate — "
                                        "hover-revealed row controls appear instantly (§1.7 瞬变清单)")
                            break
                        lvl += oc.count("{") + oc.count("[") - oc.count("}") - oc.count("]")

        opens = code.count("{") + code.count("[")
        closes = code.count("}") + code.count("]")
        if DELEGATE_ITEM.search(code) and delegate_depth is None:
            delegate_depth = depth
        for _ in range(opens):
            stack.append(idx)
        for _ in range(closes):
            if stack:
                stack.pop()
        depth += opens - closes
        if opens > closes:
            opener[depth] = idx
    return problems


def main():
    curves = style_curves()
    if not curves:
        print("check-motion: Style.qml has no `curves` map", file=sys.stderr)
        return 1
    problems = []
    for path in sorted(ROOT.rglob("*.qml")):
        rel = path.relative_to(ROOT)
        if any(part in EXCLUDED_DIRS for part in rel.parts):
            continue
        problems.extend(check_file(path, curves))
    if problems:
        for p in problems:
            print(p)
        print(f"\n{len(problems)} motion violation(s). See DESIGN.md §1.7.", file=sys.stderr)
        return 1
    print("motion ok: animations use NAnim/NColorAnim on §1.7 curves and token durations; loops honour reduceMotion")
    return 0


if __name__ == "__main__":
    sys.exit(main())
