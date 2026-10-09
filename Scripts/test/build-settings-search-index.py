#!/usr/bin/env python3
"""
Build settings search index from QML source files.

Parses the settings tab QML files to extract searchable metadata
(i18n keys, widget types, tab/sub-tab locations, visibility conditions).

Output: Assets/settings-search-index.json

Consumer contract (SettingsModuleView.searchResultClicked /
SettingsPanelService.openToEntry / Launcher SettingsProvider):
  entry.tab     = SettingsPanel.Tab enum ordinal (declaration order from 0)
  entry.subTab  = NTabView child index inside the tab, or null for the
                  module page itself (dialogs, popups, single-page tabs)
  tabLabel / subTabLabel = i18n keys for the breadcrumb

Tab -> component mapping is read from SettingsModuleView._tabComponent
(switch cases + trailing Component{id} declarations). When two enum values
share one component, the entry keeps the enum value
ControlCenterModules.moduleForTab can resolve so search clicks never fall
through to null. (Tab.Advanced and Tab.Bar currently have neither a module
nor a component — the 高级 module hosts HooksTab; bar/dock settings moved
into DockTab.)

Scan scopes:
  Modules/Panels/Settings/Tabs/**                  -> owning tab / subtab
  Modules/Panels/Settings/Bar/WidgetSettings/**    -> Tab.Dock, Plugins subtab
  Modules/Panels/Settings/DesktopWidgets/WidgetSettings/**
                                                   -> Tab.DesktopWidgets page
  Modules/Panels/Settings/ControlCenter/**         -> Tab.ControlCenter page

Usage:
  python Scripts/test/build-settings-search-index.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SETTINGS_DIR = ROOT / "Modules" / "Panels" / "Settings"
TABS_DIR = SETTINGS_DIR / "Tabs"
BAR_WS_DIR = SETTINGS_DIR / "Bar" / "WidgetSettings"
DESKTOP_WS_DIR = SETTINGS_DIR / "DesktopWidgets" / "WidgetSettings"
CC_DIR = SETTINGS_DIR / "ControlCenter"
PANEL_QML = SETTINGS_DIR / "SettingsPanel.qml"
MODULEVIEW_QML = ROOT / "Modules" / "Panels" / "ControlCenter" / "SettingsModuleView.qml"
MODULES_QML = ROOT / "Modules" / "Panels" / "ControlCenter" / "ControlCenterModules.qml"
EN_JSON = ROOT / "Assets" / "Translations" / "en.json"
OUTPUT = ROOT / "Assets" / "settings-search-index.json"

# Breadcrumb label per Tab enum name. Reuses long-standing panels.*.title
# keys (still in en.json) so no translation churn; Advanced never had one
# and uses its control-center module label.
TAB_LABELS = {
    "Advanced": "control-center.module.advanced",
    "About": "panels.about.title",
    "Audio": "panels.audio.title",
    "Bar": "panels.bar.title",
    "ColorScheme": "panels.color-scheme.title",
    "LockScreen": "panels.lock-screen.title",
    "ControlCenter": "panels.control-center.title",
    "DesktopWidgets": "panels.desktop-widgets.title",
    "OSD": "panels.osd.title",
    "Display": "panels.display.title",
    "Dock": "panels.dock.title",
    "General": "common.general",
    "Hooks": "panels.hooks.title",
    "Idle": "panels.idle.title",
    "Launcher": "panels.launcher.title",
    "Location": "panels.region.title",
    "Connections": "panels.connections.title",
    "Notifications": "common.notifications",
    "Plugins": "panels.plugins.title",
    "SessionMenu": "session-menu.title",
    "System": "panels.system.title",
    "UserInterface": "panels.user-interface.title",
    "Wallpaper": "common.wallpaper",
}

RE_LABEL = re.compile(r'label:\s*I18n\.tr\("([^"]*)"')
RE_DESCRIPTION = re.compile(r'description:\s*I18n\.tr\("([^"]*)"')
RE_VISIBLE = re.compile(r"^\s*visible:\s*(.+?)(?:\s*;)?\s*$")
RE_TYPE_OPEN = re.compile(r"(\w+)\s*\{")
RE_TAB_BUTTON = re.compile(r'text:\s*I18n\.tr\("([^"]+)"')
RE_SUBTAB_INST = re.compile(r"(\w+)\s*\{")

# Prefixes that indicate externally-resolvable conditions (singleton services or globals).
# Conditions referencing local variables (root., parent., model, index, etc.) are skipped.
RESOLVABLE_PREFIXES = (
    "CompositorService.",
    "Settings.",
    "Settings?.",
    "Quickshell.",
    "IdleService.",
    "SystemStatService.",
    "SoundService.",
    "BluetoothService.",
    "LocationService.",
    "false",
)


def parse_tab_enum(content: str) -> dict[str, int]:
    """Parse `enum Tab { ... }` ordinals (declaration order from 0)."""
    m = re.search(r"enum\s+Tab\s*\{(.*?)\}", content, re.DOTALL)
    if not m:
        return {}
    names = [n.strip().rstrip(",") for n in m.group(1).split()]
    names = [n.rstrip(",") for n in names if n and n != ","]
    # entries may carry trailing commas glued to the name
    clean = []
    for n in names:
        n = n.strip()
        if not n or n.startswith("//"):
            continue
        clean.append(n.rstrip(","))
    return {name: idx for idx, name in enumerate(clean)}


def parse_tab_components(content: str) -> dict[str, str]:
    """
    Parse _tabComponent switch (case Tab.X: return yId) plus trailing
    Component { id: yId; TypeName {} } declarations.

    Returns: Tab enum name -> QML type name (e.g. "Location" -> "RegionTab").
    """
    case_to_comp = dict(
        re.findall(r"case\s+SettingsPanel\.Tab\.(\w+)\s*:\s*\n?\s*return\s+(\w+)", content)
    )
    comp_to_type = dict(
        re.findall(r"Component\s*\{\s*\n\s*id:\s*(\w+)\s*\n\s*(\w+)\s*\{", content)
    )
    result = {}
    for tab_name, comp_id in case_to_comp.items():
        type_name = comp_to_type.get(comp_id)
        if type_name:
            result[tab_name] = type_name
    return result


def parse_routed_tabs(content: str) -> set[str]:
    """Tab enum names referenced by ControlCenterModules (moduleForTab targets)."""
    return set(re.findall(r"SettingsPanel\.Tab\.(\w+)", content))


def parse_subtabs(tab_file: Path) -> tuple[list[str], list]:
    """
    Parse a tab root file for NTabBar labels + NTabView child order.

    Returns: (child_type_names, label_keys) aligned by index.
    Files without NTabView yield ([], []).
    """
    try:
        content = tab_file.read_text()
    except OSError:
        return [], []
    lines = content.splitlines()

    def collect(marker: str, pattern: re.Pattern) -> list:
        items = []
        depth = 0
        active = False
        for line in lines:
            stripped = line.strip()
            if not active:
                if re.match(marker + r"\s*\{", stripped):
                    active = True
                    depth = 1
                continue
            depth += stripped.count("{") - stripped.count("}")
            if depth <= 0:
                break
            m = pattern.search(stripped) if marker == "NTabBar" else pattern.match(stripped)
            if m:
                items.append(m.group(1))
        return items

    labels = collect("NTabBar", RE_TAB_BUTTON)
    children = collect("NTabView", RE_SUBTAB_INST)
    while len(labels) < len(children):
        labels.append(None)
    return children, labels[: len(children)]


def is_resolvable_condition(cond: str) -> bool:
    """Check if a visibility condition can be resolved at runtime by the shell."""
    check = cond.lstrip("!").lstrip(" ").lstrip("(").lstrip(" ")
    return any(check.startswith(p) for p in RESOLVABLE_PREFIXES)


def build_scopes(content: str):
    """
    Brace-track the file. Returns per-line scope stacks plus scope conditions.

    lines_scopes[i] = list of scope ids enclosing line i (outermost first).
    scope_type = QML type of the opener, or None for untyped braces.
    scope_cond = visible: condition attached to the scope, if any.
    """
    lines = content.splitlines()
    lines_scopes: list[list[int]] = []
    scope_type: dict[int, str | None] = {}
    scope_cond: dict[int, str] = {}
    stack: list[int] = []
    next_id = 0
    for raw in lines:
        stripped = raw.strip()
        lines_scopes.append(list(stack))
        for m in RE_TYPE_OPEN.finditer(stripped):
            # only treat capitalized words as QML types; lowercase openers
            # (else {, etc.) still push an untyped scope for depth tracking
            word = m.group(1)
            scope_type[next_id] = word if word[:1].isupper() else None
            stack.append(next_id)
            next_id += 1
        # account for untyped braces (function bodies, if blocks, object
        # literals) so depth stays aligned with closing braces
        n_open = stripped.count("{") - len(RE_TYPE_OPEN.findall(stripped))
        for _ in range(n_open):
            scope_type[next_id] = None
            stack.append(next_id)
            next_id += 1
        vis = RE_VISIBLE.match(stripped)
        if vis and stack:
            cond = vis.group(1).strip()
            if cond != "true":
                scope_cond[stack[-1]] = cond
        for _ in range(stripped.count("}")):
            if stack:
                stack.pop()
    return lines, lines_scopes, scope_type, scope_cond


def extract_entries(
    qml_file: Path,
    tab_index: int,
    tab_label: str,
    sub_tab: int | None,
    sub_tab_label: str | None,
) -> list[dict]:
    """Extract searchable entries; widget = innermost typed container."""
    try:
        content = qml_file.read_text()
    except OSError as e:
        print(f"Warning: cannot read {qml_file}: {e}", file=sys.stderr)
        return []
    lines, lines_scopes, scope_type, scope_cond = build_scopes(content)
    entries = []
    for i, raw in enumerate(lines):
        lm = RE_LABEL.search(raw)
        if not lm:
            continue
        label_key = lm.group(1)
        if label_key.endswith("."):
            continue  # dynamic I18n prefix, not a real key
        stack = lines_scopes[i]
        widget = None
        inner_id = None
        for sid in reversed(stack):
            if scope_type.get(sid):
                widget = scope_type[sid]
                inner_id = sid
                break
        # same-line single-line block: opener is on this line, not in stack
        if widget is None:
            m = RE_TYPE_OPEN.search(raw.strip())
            if m and m.group(1)[:1].isupper():
                widget = m.group(1)
        if widget is None:
            continue
        # block range of the innermost scope for description/own-visible lookup
        if inner_id is not None:
            end = i
            for j in range(i + 1, len(lines)):
                if inner_id in lines_scopes[j]:
                    end = j
                else:
                    break
            block = "\n".join(lines[i : end + 1])
        else:
            block = raw
        desc = RE_DESCRIPTION.search(block)
        desc_key = desc.group(1) if desc else None
        conditions = [scope_cond[s] for s in stack if s in scope_cond]
        own = RE_VISIBLE.search(block)
        if own:
            cond = own.group(1).strip()
            if cond != "true" and cond not in conditions:
                conditions.append(cond)
        conditions = [c for c in conditions if is_resolvable_condition(c)]
        entry = {
            "labelKey": label_key,
            "descriptionKey": desc_key,
            "widget": widget,
            "tab": tab_index,
            "tabLabel": tab_label,
            "subTab": sub_tab,
        }
        if sub_tab_label is not None:
            entry["subTabLabel"] = sub_tab_label
        if conditions:
            entry["visibleWhen"] = conditions
        entries.append(entry)
    return entries


def flat_keys(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from flat_keys(v, f"{prefix}{k}.")
    else:
        yield prefix[:-1]


def main():
    for needed in (TABS_DIR, PANEL_QML, MODULEVIEW_QML):
        if not needed.exists():
            print(f"Error: required path not found: {needed}", file=sys.stderr)
            sys.exit(1)

    tab_enum = parse_tab_enum(PANEL_QML.read_text())
    if not tab_enum:
        print("Error: could not parse enum Tab from SettingsPanel.qml", file=sys.stderr)
        sys.exit(1)
    print(f"Parsed {len(tab_enum)} Tab enum values from SettingsPanel.qml")

    tab_to_type = parse_tab_components(MODULEVIEW_QML.read_text())
    if not tab_to_type:
        print("Error: could not parse _tabComponent from SettingsModuleView.qml", file=sys.stderr)
        sys.exit(1)

    # QML type name -> defining file under Tabs/
    type_to_file: dict[str, Path] = {}
    for f in TABS_DIR.rglob("*.qml"):
        if f.stem.endswith("Tab") and not f.stem.endswith("SubTab"):
            if f.stem in type_to_file:
                print(f"Warning: duplicate *Tab.qml for {f.stem}", file=sys.stderr)
            type_to_file.setdefault(f.stem, f)

    routed = parse_routed_tabs(MODULES_QML.read_text()) if MODULES_QML.exists() else set()

    # Tab enum value -> root tab file. If two enum values ever share one
    # component, only the moduleForTab-routable one is kept.
    file_to_tabs: dict[Path, list[str]] = {}
    for tab_name, type_name in tab_to_type.items():
        f = type_to_file.get(type_name)
        if f is None:
            print(f"Warning: no file for component {type_name} (Tab.{tab_name})", file=sys.stderr)
            continue
        file_to_tabs.setdefault(f, []).append(tab_name)
    tab_file: dict[str, Path] = {}
    for f, names in file_to_tabs.items():
        if len(names) > 1:
            preferred = [n for n in names if n in routed] or [names[0]]
            dropped = [n for n in names if n not in preferred]
            if dropped:
                print(f"Dropped unroutable shim tab(s) {dropped} sharing {f.name}")
            names = preferred
        for n in names:
            tab_file[n] = f

    missing_labels = [k for k in TAB_LABELS.values() if k not in set(flat_keys(json.loads(EN_JSON.read_text())))] if EN_JSON.exists() else []
    for k in missing_labels:
        print(f"Warning: tabLabel key missing from en.json: {k}", file=sys.stderr)

    # Per-tab subtab tables from each root tab file's NTabBar/NTabView.
    subtab_table: dict[str, tuple[list[str], list]] = {}
    for tab_name, f in tab_file.items():
        subtab_table[tab_name] = parse_subtabs(f)
    type_to_tab = {t: n for n, t in tab_to_type.items() if n in tab_file}

    dock_children, dock_labels = subtab_table.get("Dock", ([], []))
    try:
        plugins_idx = dock_children.index("PluginsSubTab")
        plugins_label = dock_labels[plugins_idx]
    except ValueError:
        plugins_idx, plugins_label = None, None
        print("Warning: PluginsSubTab not found in DockTab; Bar widget settings skipped", file=sys.stderr)

    def tabs_attribution(qml_file: Path):
        """Attribution for files under Tabs/."""
        stem = qml_file.stem
        parent = qml_file.parent
        if parent == TABS_DIR:
            # root tab file (GeneralTab, DesktopWidgetsTab): own widgets -> page
            tab_name = type_to_tab.get(stem)
            if tab_name is None:
                return None
            return (tab_name, None, None)
        dir_tab_type = f"{parent.name}Tab"
        tab_name = type_to_tab.get(dir_tab_type)
        if tab_name is None:
            print(f"Warning: no tab for directory {parent.name} ({qml_file})", file=sys.stderr)
            return None
        if stem == dir_tab_type:
            return (tab_name, None, None)
        children, labels = subtab_table.get(tab_name, ([], []))
        if stem in children:
            idx = children.index(stem)
            return (tab_name, idx, labels[idx])
        # dialogs / popups / rows: attribute to the module page itself
        return (tab_name, None, None)

    scan_lists: list[tuple[Path, object]] = []
    scan_lists.extend((f, "tabs") for f in sorted(TABS_DIR.rglob("*.qml")))
    if BAR_WS_DIR.exists() and plugins_idx is not None:
        scan_lists.extend((f, "bar") for f in sorted(BAR_WS_DIR.rglob("*.qml")))
    if DESKTOP_WS_DIR.exists():
        scan_lists.extend((f, "desktop") for f in sorted(DESKTOP_WS_DIR.rglob("*.qml")))
    if CC_DIR.exists():
        scan_lists.extend((f, "cc") for f in sorted(CC_DIR.rglob("*.qml")))

    all_entries = []
    seen_labels = set()
    for qml_file, kind in scan_lists:
        if kind == "tabs":
            attr = tabs_attribution(qml_file)
        elif kind == "bar":
            attr = ("Dock", plugins_idx, plugins_label)
        elif kind == "desktop":
            attr = ("DesktopWidgets", None, None)
        else:
            attr = ("ControlCenter", None, None)
        if attr is None:
            continue
        tab_name, sub_tab, sub_tab_label = attr
        if tab_name not in tab_enum:
            print(f"Warning: Tab.{tab_name} not in enum ({qml_file})", file=sys.stderr)
            continue
        entries = extract_entries(qml_file, tab_enum[tab_name], TAB_LABELS[tab_name], sub_tab, sub_tab_label)
        for entry in entries:
            if entry["labelKey"] not in seen_labels:
                seen_labels.add(entry["labelKey"])
                all_entries.append(entry)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT, "w") as f:
        json.dump(all_entries, f, indent=2)

    print(f"Generated {len(all_entries)} entries -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
