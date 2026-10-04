pragma Singleton

import QtQuick
import Quickshell
import qs.Modules.Panels.Settings
import qs.Services.Networking
import qs.Commons

/**
* ControlCenterModules - the DDE 15 module grid model (DESIGN §3.5.2).
*
* Ordering follows DDE's own navigation bar (gxde-control-center
* navigationbar.cpp:39-85); each entry maps to the Noctalia settings tab it
* opens in this phase (5b embeds the settings pages inside the frame).
* `visible` is a predicate evaluated per screen, so optional entries (e.g.
* 蓝牙 without an adapter) disappear instead of showing a dead cell.
*/
Singleton {
  id: root

  function tr(key) {
    return I18n ? I18n.tr(key) : key;
  }

  readonly property var modules: [
    {
      "id": "accounts",
      "label": "control-center.module.accounts",
      "icon": "person",
      "tab": SettingsPanel.Tab.General,
      "subTab": -1
    },
    {
      "id": "display",
      "label": "control-center.module.display",
      "icon": "settings-display",
      "tab": SettingsPanel.Tab.Display,
      "subTab": -1
    },
    {
      "id": "personalization",
      "label": "control-center.module.personalization",
      "icon": "palette",
      "tab": SettingsPanel.Tab.ColorScheme,
      "subTab": -1
    },
    {
      "id": "dock",
      "label": "control-center.module.taskbar",
      "icon": "layout-bottombar",
      "tab": SettingsPanel.Tab.Dock,
      "subTab": -1
    },
    {
      "id": "launcher",
      "label": "control-center.module.launcher",
      "icon": "rocket",
      "tab": SettingsPanel.Tab.Launcher,
      "subTab": -1
    },
    {
      "id": "network",
      "label": "control-center.module.network",
      "icon": "wifi",
      "tab": SettingsPanel.Tab.Connections,
      "subTab": 0
    },
    {
      "id": "bluetooth",
      "label": "control-center.module.bluetooth",
      "icon": "bluetooth",
      "tab": SettingsPanel.Tab.Connections,
      "subTab": 1
    },
    {
      "id": "sound",
      "label": "control-center.module.sound",
      "icon": "device-speaker",
      "tab": SettingsPanel.Tab.Audio,
      "subTab": -1
    },
    {
      "id": "notifications",
      "label": "control-center.module.notifications",
      "icon": "bell",
      "tab": SettingsPanel.Tab.Notifications,
      "subTab": -1
    },
    {
      "id": "datetime",
      "label": "control-center.module.datetime",
      "icon": "clock",
      "tab": SettingsPanel.Tab.Location,
      "subTab": 1
    },
    {
      "id": "power",
      "label": "control-center.module.power",
      "icon": "moon",
      "tab": SettingsPanel.Tab.Idle,
      "subTab": -1
    },
    {
      "id": "keyboard",
      "label": "control-center.module.keyboard",
      "icon": "keyboard",
      "tab": SettingsPanel.Tab.General,
      "subTab": 1
    },
    {
      "id": "desktopwidgets",
      "label": "control-center.module.desktop-widget",
      "icon": "layout-board",
      "tab": SettingsPanel.Tab.DesktopWidgets,
      "subTab": -1
    },
    {
      "id": "systemmonitor",
      "label": "control-center.module.system-monitor",
      "icon": "activity",
      "tab": SettingsPanel.Tab.System,
      "subTab": -1
    },
    {
      "id": "plugins",
      "label": "control-center.module.plugins",
      "icon": "plug-connected",
      "tab": SettingsPanel.Tab.Plugins,
      "subTab": -1
    },
    {
      "id": "advanced",
      "label": "control-center.module.advanced",
      "icon": "link",
      "tab": SettingsPanel.Tab.Hooks,
      "subTab": -1
    },
    {
      "id": "systeminfo",
      "label": "control-center.module.system-info",
      "icon": "info-square-rounded",
      "tab": SettingsPanel.Tab.About,
      "subTab": -1
    }
  ]

  function isVisible(module) {
    if (module.id === "bluetooth")
      return BluetoothService.bluetoothAvailable;
    return true;
  }

  function open(module, screen) {
    if (!module)
      return;
    Logger.d("ControlCenterModules", "Opening", module.id, "-> tab", module.tab);
    SettingsPanelService.openToTab(module.tab, module.subTab, screen);
  }
}
