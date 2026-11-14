#!/usr/bin/env python3
"""Ban raw color and size literals outside the token layer.

CODING_STANDARDS.md「令牌」: colors read `Colors.*`, sizes, radii and
durations read `Style.*`; a new value first becomes a token, then gets
used. This check is the lint half of that rule — the QML-side equivalent
of a design-system linter's no-raw-colors / no-arbitrary-values.

Colors, flagged anywhere in a component:
  - "#hex" literals, incl. canvas `ctx.fillStyle = "#fff"`.
  - Named colors ("white", "black", ...) on a color-ish line
    (color:/Color:/fillStyle/strokeStyle). "transparent" is exempt: it is
    the absence of a color, not a palette value.
  - Qt.rgba/hsla/hsva with >= 2 numeric channel literals — a hand-mixed
    color. Channel math on an existing token (Qt.rgba(c.r, c.g, c.b, a))
    is derivation, not a raw literal, and passes.
  - Qt.darker/lighter/tint always: a hand-derived theme color is exactly
    the divergence the mHover/onHover tokens exist to prevent.

Sizes, flagged on the style-visible geometry properties below:
  - Any numeric literal >= 2. 0 and 1 are exempt: 0 is structural
    (spacing: 0, width: 0), 1 is a hairline that stays a hairline at any
    uiScaleRatio.
  - Only a bare literal assignment is flagged (`width: 28`). Once an
    operator follows (`width: 2 * Style.marginS`) the value is already an
    expression over tokens and passes.
  - The last property segment is matched, so anchors.margins,
    Layout.preferredWidth, font.pixelSize, border.width are all covered.

Exemptions:
  - EXEMPT_FILES own the values (token layer, settings defaults, color
    editing/generation internals, alpha-mask gradients).
  - A trailing `// nosd:raw-ok <reason>` exempts one line; the reason is
    mandatory so the exception is greppable and self-documenting.

Usage:
  Scripts/dev/check-raw-values.py    # exit 1 on any hit
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SKIP_DIRS = {"references", "docs", "tools", "node_modules", "__pycache__"}

# Files that legitimately own raw values.
EXEMPT_FILES = {
    Path("Commons/Colors.qml"),                        # color token definitions
    Path("Commons/Style.qml"),                         # size/motion token definitions
    Path("Commons/Settings.qml"),                      # user-pref defaults (fillColor, solidColor…)
    Path("Services/Theming/ColorSchemeService.qml"),   # generates the app theme exports
    Path("Widgets/NColorPicker.qml"),                  # color-editing internals
    Path("Widgets/NColorPickerDialog.qml"),
    Path("Widgets/NColorSlider.qml"),
    Path("Widgets/NScrollEdgeMask.qml"),               # alpha-mask gradient, not paint colors
}

RAW_OK = re.compile(r"//\s*nosd:raw-ok\s+\S")

# --- colors ---------------------------------------------------------------
HEX = re.compile(r'"#[0-9a-fA-F]{3,8}"')
NAMED = re.compile(r'"(?:white|black|red|green|blue|grey|gray|yellow|orange|purple|pink|cyan|magenta|brown)"')
COLOR_CTX = re.compile(r"color|fillStyle|strokeStyle", re.IGNORECASE)
QT_DERIVE = re.compile(r"Qt\.(?:darker|lighter|tint)\s*\(")
QT_CHANNELS = re.compile(r"Qt\.(?:rgba|hsla|hsva)\s*\(([^)]*)\)")
NUM = re.compile(r"^-?\d+(?:\.\d+)?$")


def color_hit(code):
    if HEX.search(code):
        return "hex color literal"
    if NAMED.search(code) and COLOR_CTX.search(code):
        return "named color literal"
    if QT_DERIVE.search(code):
        return "Qt.darker/lighter/tint derives a theme color by hand"
    for m in QT_CHANNELS.finditer(code):
        args = [a.strip() for a in m.group(1).split(",")]
        if sum(1 for a in args[:3] if NUM.match(a)) >= 2:
            return "Qt.rgba/hsla/hsva with literal channels"
    return None


# --- sizes ----------------------------------------------------------------
GEOM_PROPS = (
    "width|height|implicitWidth|implicitHeight|preferredWidth|preferredHeight"
    "|minimumWidth|minimumHeight|maximumWidth|maximumHeight|cellWidth|cellHeight"
    "|radius|spacing|rowSpacing|columnSpacing"
    "|padding|leftPadding|rightPadding|topPadding|bottomPadding"
    "|horizontalPadding|verticalPadding"
    "|margins|leftMargin|rightMargin|topMargin|bottomMargin"
    "|pixelSize|pointSize|fontSize|iconSize|borderWidth|lineWidth"
)
# `prop:` with no space before the colon excludes ternary else-branches
# (`cond ? a.width : 400`), where `width :` ends an expression, not a
# declaration. QML declarations in this codebase never space the colon.
GEOM = re.compile(rf"(?:^|[.\s{{(])({GEOM_PROPS}):\s*(-?\d+(?:\.\d+)?)\s*(?://.*)?$")


def size_hit(code):
    m = GEOM.search(code)
    if not m:
        return None
    value = float(m.group(2))
    if abs(value) < 2:
        return None
    return f"{m.group(1)}: {m.group(2)}"


def main():
    hits = []
    for path in sorted(ROOT.rglob("*.qml")):
        rel = path.relative_to(ROOT)
        if rel in EXEMPT_FILES:
            continue
        if any(part in SKIP_DIRS or part.startswith(".") for part in rel.parts):
            continue
        for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            code = line.split("//", 1)[0].strip()
            if not code:
                continue
            problems = [p for p in (color_hit(code), size_hit(code)) if p]
            if not problems:
                continue
            if RAW_OK.search(line):
                continue
            hits.append(f"{rel}:{n}  {', '.join(problems)}\n    {line.strip()}")
    if hits:
        print(f"{len(hits)} raw value(s) outside the token layer:")
        for h in hits:
            print(f"  {h}")
        print(
            "\nFix: read Colors.*/Style.* — spacing/margins use Style.margin*, radii\n"
            "Style.radius*, borders Style.border*, fonts Style.fontSize*, named\n"
            "values get a semantic token first (AGENTS.md「依据」). Legitimate raw\n"
            "values take a `// nosd:raw-ok <reason>` on the same line."
        )
        return 1
    print("raw values ok: colors and sizes outside the token layer are token-driven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
