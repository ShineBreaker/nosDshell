#!/usr/bin/env python3
"""Check that dates and times go through Commons/Time.qml, not Qt locale APIs.

Date/time text must follow the interface language (DESIGN.md §1.5): long
dates use `Time.formatLongDate(date)`, "month + year" uses
`Time.formatMonthYear(date)`, both built on `I18n.locale`. `Qt.formatDate`,
`Qt.formatDateTime`, `Qt.formatTime` and `toLocale*String(Qt.locale())`
format by the system locale instead, so a Chinese interface can sprout
English dates. Localized month/day names must not be uppercased either (§7).

Flags, per offending line:
1. `Qt.formatDate` / `Qt.formatDateTime` / `Qt.formatTime` calls.
2. `.toLocaleDateString(` / `.toLocaleTimeString(` / `.toLocaleString(` calls.
3. `monthName(` / `dayName(` with `.toUpperCase(` on the same line.

`Commons/Time.qml` and `Commons/I18n.qml` define the blessed path, so they
are exempt. A line carrying `// locale-exempt` is exempt too: purely numeric
formatting (clock digits, log timestamps) is locale-independent by
construction, and the marker keeps that reasoning visible at the call site.

Usage:
  Scripts/dev/check-locale-format.py     # exit 1 if any problem is found
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
EXCLUDED_DIRS = {"references", "docs", ".git", "target", "node_modules", "__pycache__"}
EXEMPT_FILES = {Path("Commons/Time.qml"), Path("Commons/I18n.qml")}
EXEMPT_MARKER = "// locale-exempt"

QT_FORMAT = re.compile(r"\bQt\.format(Date|DateTime|Time)\b")
TOLOCALE_CALL = re.compile(r"\.toLocale(Date|Time)?String\s*\(")
MONTH_DAY_CALL = re.compile(r"\b(monthName|dayName)\s*\(")
UPPER_CALL = re.compile(r"\.toUpperCase\s*\(")


def strip_code(line):
    """Drop line comments and string literals so prose can't match."""
    line = line.split("//", 1)[0]
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def check_file(path):
    problems = []
    for idx, raw in enumerate(path.read_text(errors="replace").splitlines()):
        if EXEMPT_MARKER in raw:
            continue
        code = strip_code(raw)
        if QT_FORMAT.search(code):
            problems.append((idx + 1, raw.strip(), "use Time.formatLongDate/formatMonthYear (I18n.locale), not Qt.format* (system locale)"))
        elif TOLOCALE_CALL.search(code):
            problems.append((idx + 1, raw.strip(), "use Time.formatLongDate/formatMonthYear (I18n.locale), not toLocale*String(Qt.locale())"))
        elif MONTH_DAY_CALL.search(code) and UPPER_CALL.search(code):
            problems.append((idx + 1, raw.strip(), "localized month/day names must not be uppercased (DESIGN.md §1.5, §7)"))
    return problems


def main():
    problems = []
    for suffix in ("*.qml", "*.js"):
        for path in sorted(ROOT.rglob(suffix)):
            rel = path.relative_to(ROOT)
            if any(part in EXCLUDED_DIRS for part in rel.parts):
                continue
            if rel in EXEMPT_FILES:
                continue
            for line, content, hint in check_file(path):
                problems.append(f"{rel}:{line}: {content}  [{hint}]")

    if problems:
        for p in problems:
            print(p)
        print(f"\n{len(problems)} locale-format problem(s). Route date/time text through "
              "Commons/Time.qml; mark provably locale-independent numeric formatting "
              "with `// locale-exempt` (DESIGN.md §1.5).", file=sys.stderr)
        return 1
    print("locale format ok: no Qt.format*/toLocale*String calls, no uppercased month/day names")
    return 0


if __name__ == "__main__":
    sys.exit(main())
