pragma Singleton

import QtQuick
import Quickshell
import qs.Modules.Panels.Settings
import qs.Services.Networking
import qs.Commons

/**
* ControlCenterModules - the DDE 15 module model (DESIGN §3.5.2–3.5.3).
*
* Ordering follows DDE's own navigation bar; each entry maps to the Noctalia
* settings tab(s) it opens inside the control center frame. `tabs` holds every
* tab a module shows, so multi-tab modules (个性化, 任务栏, 电源 …) render their
* tabs as stacked SettingsGroups on one page. `subTab` names the single inner
* group the module owns when it covers only one slice of a shared tab (蓝牙
* owns Connections' group 1, 键盘 owns General's keybinds); -1 shows the whole
* tab. Every inner group of every tab must be reachable through some entry —
* a `subTab` slice hides its siblings under other modules.
*
* This list is the single source of truth for the home grid, the module view's
* rail and `settings openTab` routing.
* `visible` is evaluated per screen, so optional entries (e.g. 蓝牙 without an
* adapter) disappear instead of showing a dead cell.
*/
Singleton {
    id: root

    function tr(key) {
        return I18n ? I18n.tr(key) : key;
    }

    readonly property var modules: [
        {
            "id": "accounts",
            "ddeIcon": "accounts",
            "label": "control-center.module.accounts",
            "icon": "person",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.General,
                    "subTab": 0
                }
            ]
        },
        {
            "id": "display",
            "ddeIcon": "display",
            "label": "control-center.module.display",
            "icon": "settings-display",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Display,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "personalization",
            "ddeIcon": "personalization",
            "label": "control-center.module.personalization",
            "icon": "palette",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.ColorScheme,
                    "subTab": -1
                },
                {
                    "tab": SettingsPanel.Tab.Wallpaper,
                    "subTab": -1
                },
                {
                    "tab": SettingsPanel.Tab.UserInterface,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "dock",
            "ddeIcon": "dock",
            "label": "control-center.module.taskbar",
            "icon": "layout-bottombar",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Dock,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "launcher",
            "ddeIcon": "launcher",
            "label": "control-center.module.launcher",
            "icon": "rocket",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Launcher,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "controlcenter",
            "ddeIcon": "controlcenter",
            "label": "control-center.module.control-center",
            "icon": "settings-control-center",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.ControlCenter,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "network",
            "ddeIcon": "network",
            "label": "control-center.module.network",
            "icon": "wifi",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Connections,
                    "subTab": 0
                }
            ]
        },
        {
            "id": "bluetooth",
            "ddeIcon": "bluetooth",
            "label": "control-center.module.bluetooth",
            "icon": "bluetooth",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Connections,
                    "subTab": 1
                }
            ]
        },
        {
            "id": "sound",
            "ddeIcon": "sound",
            "label": "control-center.module.sound",
            "icon": "device-speaker",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Audio,
                    "subTab": -1
                },
                {
                    "tab": SettingsPanel.Tab.OSD,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "notifications",
            "ddeIcon": "notifications",
            "label": "control-center.module.notifications",
            "icon": "bell",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Notifications,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "datetime",
            "ddeIcon": "datetime",
            "label": "control-center.module.datetime",
            "icon": "clock",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Location,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "power",
            "ddeIcon": "power",
            "label": "control-center.module.power",
            "icon": "moon",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Idle,
                    "subTab": -1
                },
                {
                    "tab": SettingsPanel.Tab.SessionMenu,
                    "subTab": -1
                },
                {
                    "tab": SettingsPanel.Tab.LockScreen,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "keyboard",
            "ddeIcon": "keyboard",
            "label": "control-center.module.keyboard",
            "icon": "keyboard",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.General,
                    "subTab": 1
                }
            ]
        },
        {
            "id": "desktopwidgets",
            "ddeIcon": "desktopwidgets",
            "label": "control-center.module.desktop-widget",
            "icon": "layout-board",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.DesktopWidgets,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "systemmonitor",
            "ddeIcon": "systemmonitor",
            "label": "control-center.module.system-monitor",
            "icon": "activity",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.System,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "plugins",
            "ddeIcon": "plugins",
            "label": "control-center.module.plugins",
            "icon": "plug-connected",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Plugins,
                    "subTab": -1
                }
            ]
        },
        {
            // Overflow shelf is gone — everything it held moved to its
            // semantic module (taskbar/monitors → 任务栏, panels & corners →
            // 个性化). 高级 now means "things with no DDE home at all": hooks.
            "id": "advanced",
            "ddeIcon": "advanced",
            "label": "control-center.module.advanced",
            "icon": "link",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.Hooks,
                    "subTab": -1
                }
            ]
        },
        {
            "id": "systeminfo",
            "ddeIcon": "systeminfo",
            "label": "control-center.module.system-info",
            "icon": "info-square-rounded",
            "tabs": [
                {
                    "tab": SettingsPanel.Tab.About,
                    "subTab": -1
                }
            ]
        }
    ]

    function isVisible(module) {
        if (module.id === "bluetooth")
            return BluetoothService.bluetoothAvailable;
        return true;
    }

    // DDE 15 original navigation artwork (DESIGN §1.9/§3.5.3): selected state
    // uses nav_<m>.svg, default state nav_<m>_normal.svg. Returns "" when the
    // module has no artwork (caller falls back to a Tabler glyph).
    //
    // Modules that exist only in nosDshell (no upstream counterpart) carry
    // same-style artwork drawn in-house under Assets/Nav/ — mixing real DDE
    // fills with Tabler strokes made the rail read as two different icon sets.
    readonly property var nosdNavIcons: ["advanced", "controlcenter", "desktopwidgets", "dock", "launcher", "notifications", "plugins", "systemmonitor"]

    function navIconUrl(module, selected) {
        if (!module || !module.ddeIcon)
            return "";
        const suffix = selected ? "" : "_normal";
        if (nosdNavIcons.indexOf(module.ddeIcon) >= 0)
            return Quickshell.shellDir + "/Assets/Nav/nav_" + module.ddeIcon + suffix + ".svg";
        return Quickshell.shellDir + "/Assets/DDE/gxde-control-center/src/frame/modules/" + module.ddeIcon + "/themes/dark/icons/nav_" + module.ddeIcon + suffix + ".svg";
    }

    // First module carrying `tab`, optionally on the given sub-tab. Used by
    // `settings openTab` routing so IPC lands on the right module.
    function moduleForTab(tab, subTab) {
        const t = targetForTab(tab, subTab);
        return t ? t.module : null;
    }

    // Resolve a (tab, subTab) request to a concrete scroll target:
    //   module — owning module
    //   slot   — index into module.tabs (the tab section inside the module)
    //   inner  — sub-group index inside that tab's stacked NTabView
    // A module entry's own `subTab` is the semantic inner index it stands for
    // (e.g. bluetooth = Connections inner 1); -1 means "the whole tab" and
    // matches any requested subTab as a wildcard. Returns null when no module
    // carries the tab at all.
    function targetForTab(tab, subTab) {
        const want = (subTab === undefined || subTab === null) ? -1 : subTab;
        var loose = null;
        for (var i = 0; i < modules.length; i++) {
            const tabs = modules[i].tabs ?? [];
            for (var j = 0; j < tabs.length; j++) {
                if (tabs[j].tab !== tab)
                    continue;
                const decl = tabs[j].subTab ?? -1;
                if (want < 0 || decl < 0 || decl === want)
                    return {
                        "module": modules[i],
                        "slot": j,
                        "inner": want >= 0 ? want : decl
                    };
                // Same tab, different declared inner: remember it as a fallback — the
                // stacked view can still scroll to any group index the page owns
                // (e.g. location/0 lands on the datetime module's first group even
                // though the rail entry stands for inner 1).
                if (want >= 0 && loose === null)
                    loose = {
                        "module": modules[i],
                        "slot": j,
                        "inner": want
                    };
            }
        }
        return loose;
    }

    // ipc-friendly name or module id -> module (same strings verify.sh's settings-* use)
    readonly property var aliasMap: ({
            "about": "systeminfo",
            "audio": "sound",
            "bar": "dock",
            "colorscheme": "personalization",
            "connections": "network",
            "controlcenter": "controlcenter",
            "desktopwidgets": "desktopwidgets",
            "display": "display",
            "dock": "dock",
            "general": "accounts",
            "hooks": "advanced",
            "idle": "power",
            "launcher": "launcher",
            "location": "datetime",
            "lockscreen": "power",
            "notifications": "notifications",
            "osd": "sound",
            "plugins": "plugins",
            "sessionmenu": "power",
            "system": "systemmonitor",
            "systemmonitor": "systemmonitor",
            "userinterface": "personalization",
            "wallpaper": "personalization"
        })

    function moduleByName(name) {
        const id = aliasMap[name] ?? name;
        if (id === undefined)
            return null;
        for (var i = 0; i < modules.length; i++) {
            if (modules[i].id === id)
                return modules[i];
        }
        return null;
    }
}
