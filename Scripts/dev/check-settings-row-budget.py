#!/usr/bin/env python3
"""The settings control column has to fit in the row.

DESIGN §3.5.4: the control stays settingsFieldWidth and the title wraps in
what is left. The old floor was the DDE 140 px title column. At scale 1,

    140 + marginL + settingsFieldWidth  >  settingsRowContentMaxWidth

so a long title pushed the control through the row padding and, at the
extreme, off the panel edge. settingsFieldTitleMaxWidth is that remainder.
Field widgets must floor the title with it, not with settingsFieldTitleWidth.

Toggles and colour swatches are not the 170 px column; they may still use
the 140 px token.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
STYLE = ROOT / "Commons" / "Style.qml"
FIELD_WIDGETS = [
    "Widgets/NComboBox.qml",
    "Widgets/NSpinBox.qml",
    "Widgets/NTextInput.qml",
    "Widgets/NTextInputButton.qml",
    "Widgets/NSearchableComboBox.qml",
    "Widgets/NKeybindRecorder.qml",
]


def base(name, text):
    m = re.search(
        rf"property (?:int|real) {name}: Math\.round\((\d+) \* uiScaleRatio\)",
        text,
    )
    if not m:
        print(f"{STYLE}: cannot read {name}", file=sys.stderr)
        return None
    return int(m.group(1))


def main():
    style = STYLE.read_text()
    margin_l = base("marginL", style)
    field = base("settingsFieldWidth", style)
    row = base("settingsRowContentMaxWidth", style)
    if None in (margin_l, field, row):
        return 1
    expect = max(0, row - margin_l - field)
    if f"settingsRowContentMaxWidth - marginL - settingsFieldWidth" not in style:
        print(
            f"{STYLE}: settingsFieldTitleMaxWidth must be "
            "settingsRowContentMaxWidth - marginL - settingsFieldWidth",
            file=sys.stderr,
        )
        return 1
    if expect + margin_l + field > row:
        print(
            f"title {expect} + marginL {margin_l} + field {field} = "
            f"{expect + margin_l + field} > row {row}",
            file=sys.stderr,
        )
        return 1
    fail = 0
    for rel in FIELD_WIDGETS:
        text = (ROOT / rel).read_text()
        if "settingsFieldTitleMaxWidth" not in text:
            print(f"{rel}: title floor must use settingsFieldTitleMaxWidth", file=sys.stderr)
            fail = 1
        if "settingsFieldTitleWidth" in text:
            print(f"{rel}: still floors the title with settingsFieldTitleWidth", file=sys.stderr)
            fail = 1
    return fail


if __name__ == "__main__":
    sys.exit(main())
