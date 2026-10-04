pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.UI

// DDE dock settings menu (DESIGN §3.3 light menu): shown by right-click on
// empty dock/taskbar space in both fashion and efficient modes. Submenus for
// mode / location / size / status / plugins, plus a Settings entry.
Singleton {
  id: root

  // Widget ids that make sense as dock/taskbar plugin entries. Taskbar,
  // Launcher, Spacer and ShowDesktop are structural (taskbar built-ins or
  // ignored in fashion mode) and are intentionally not offered here.
  readonly property var pluginCandidates: [
    "Tray", "NotificationHistory", "Network", "Volume", "Microphone",
    "Brightness", "Bluetooth", "Battery", "Clock", "DarkMode", "NightLight",
    "KeepAwake", "KeyboardLayout", "LockKeys", "PowerProfile", "VPN",
    "SessionMenu", "Settings", "Trash", "Workspace", "SystemMonitor"
  ]

  property var _openMenu: null
  property var _openScreen: null

  function availablePlugins() {
    var out = [];
    for (var i = 0; i < pluginCandidates.length; i++) {
      var id = pluginCandidates[i];
      if (BarWidgetRegistry.hasWidget(id))
        out.push(id);
    }
    return out;
  }

  function buildModel() {
    var dock = Settings.data.dock;
    var plugins = dock.plugins || [];
    var enabled = {};
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i] && plugins[i].id)
        enabled[plugins[i].id] = true;
    }

    var pluginItems = [];
    var ids = availablePlugins();
    for (i = 0; i < ids.length; i++) {
      pluginItems.push({
                         "label": ids[i],
                         "action": "plugin:" + ids[i],
                         "checked": enabled[ids[i]] === true
                       });
    }

    return [
          {
            "label": I18n.tr("dock-menu.mode"),
            "hasSubmenu": true,
            "submenu": [
              {
                "label": I18n.tr("dock-menu.mode-fashion"),
                "action": "mode:fashion",
                "checked": dock.mode === "fashion"
              },
              {
                "label": I18n.tr("dock-menu.mode-efficient"),
                "action": "mode:efficient",
                "checked": dock.mode === "efficient"
              }
            ]
          },
          {
            "label": I18n.tr("dock-menu.location"),
            "hasSubmenu": true,
            "submenu": [
              {
                "label": I18n.tr("dock-menu.location-top"),
                "action": "position:top",
                "checked": dock.position === "top"
              },
              {
                "label": I18n.tr("dock-menu.location-bottom"),
                "action": "position:bottom",
                "checked": dock.position === "bottom"
              },
              {
                "label": I18n.tr("dock-menu.location-left"),
                "action": "position:left",
                "checked": dock.position === "left"
              },
              {
                "label": I18n.tr("dock-menu.location-right"),
                "action": "position:right",
                "checked": dock.position === "right"
              }
            ]
          },
          {
            "label": I18n.tr("dock-menu.size"),
            "hasSubmenu": true,
            "submenu": [
              {
                "label": I18n.tr("dock-menu.size-large"),
                "action": "size:48",
                "checked": dock.iconSize === 48
              },
              {
                "label": I18n.tr("dock-menu.size-medium"),
                "action": "size:36",
                "checked": dock.iconSize === 36
              },
              {
                "label": I18n.tr("dock-menu.size-small"),
                "action": "size:30",
                "checked": dock.iconSize === 30
              }
            ]
          },
          {
            "label": I18n.tr("dock-menu.state"),
            "hasSubmenu": true,
            "submenu": [
              {
                "label": I18n.tr("dock-menu.state-keep-showing"),
                "action": "hideMode:keep-showing",
                "checked": dock.hideMode === "keep-showing"
              },
              {
                "label": I18n.tr("dock-menu.state-keep-hidden"),
                "action": "hideMode:keep-hidden",
                "checked": dock.hideMode === "keep-hidden"
              },
              {
                "label": I18n.tr("dock-menu.state-smart-hide"),
                "action": "hideMode:smart-hide",
                "checked": dock.hideMode === "smart-hide"
              }
            ]
          },
          {
            "label": I18n.tr("dock-menu.plugins"),
            "hasSubmenu": true,
            "submenu": pluginItems
          },
          {
            "separator": true
          },
          {
            "label": I18n.tr("dock-menu.settings"),
            "action": "settings",
            "icon": "settings"
          }
        ];
  }

  // Toggle a plugin id inside dock.plugins, preserving existing order.
  function togglePlugin(id) {
    var plugins = (Settings.data.dock.plugins || []).slice();
    var idx = -1;
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i] && plugins[i].id === id) {
        idx = i;
        break;
      }
    }
    if (idx >= 0) {
      plugins.splice(idx, 1);
    } else {
      var entry = {
        "id": id
      };
      // Fill per-widget default settings the same way BarTab._addWidgetToSection does
      if (BarWidgetRegistry.widgetHasUserSettings(id)) {
        var metadata = BarWidgetRegistry.widgetMetadata[id];
        if (metadata) {
          Object.keys(metadata).forEach(function (key) {
            entry[key] = metadata[key];
          });
        }
      }
      plugins.push(entry);
    }
    Settings.data.dock.plugins = plugins;
    BarService.widgetsRevision++;
  }

  function handleAction(action, screen) {
    if (!action)
      return false;
    var dock = Settings.data.dock;
    if (action.startsWith("mode:")) {
      dock.mode = action.substring(5);
      return false;
    }
    if (action.startsWith("position:")) {
      dock.position = action.substring(9);
      return false;
    }
    if (action.startsWith("size:")) {
      dock.iconSize = parseInt(action.substring(5));
      return false;
    }
    if (action.startsWith("hideMode:")) {
      dock.hideMode = action.substring(9);
      return false;
    }
    if (action.startsWith("plugin:")) {
      togglePlugin(action.substring(7));
      // Keep the menu open and refresh the check states
      if (_openMenu)
        _openMenu.model = buildModel();
      return true;
    }
    if (action === "settings") {
      var panel = PanelService.getPanel("settingsPanel", screen);
      if (panel) {
        panel.requestedTab = SettingsPanel.Tab.Dock;
        panel.toggle();
      }
      return false;
    }
    return false;
  }

  // Open the light dock settings menu at screen coordinates.
  function openAt(screen, screenX, screenY) {
    if (!screen)
      return;
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (!popupMenuWindow) {
      Logger.w("DockSettingsMenu", "no popup menu window for screen", screen.name);
      return;
    }
    _openScreen = screen;
    _openMenu = popupMenuWindow.showDynamicContextMenu(buildModel(), screenX, screenY, function (action) {
      return root.handleAction(action, _openScreen);
    }, "light");
  }

  // Open the settings menu at the dock center and expand the first submenu.
  // Used by the dock-submenu verification scene (no input simulation exists).
  function openSubmenuPreview(screen) {
    openAtDockCenter(screen);
    Qt.callLater(() => {
                   if (!_openMenu || !_openMenu.model)
                     return;
                   for (var i = 0; i < _openMenu.model.length; i++) {
                     var item = _openMenu.model[i];
                     if (item && item.hasSubmenu === true) {
                       _openMenu.openSubmenuAt(i);
                       return;
                     }
                   }
                 });
  }

  // Convert an item-local point to screen coordinates, then open the menu.
  function openAtItemPoint(screen, item, localX, localY) {
    if (!screen || !item)
      return;
    var pos = item.mapToItem(null, localX, localY);
    var win = item.Window ? item.Window.window : null;
    var sx = pos.x + (win ? win.x - screen.x : 0);
    var sy = pos.y + (win ? win.y - screen.y : 0);
    openAt(screen, sx, sy);
  }

  // Open the menu at the visual center of the dock edge (IPC hook).
  function openAtDockCenter(screen) {
    if (!screen)
      return;
    var dock = Settings.data.dock;
    var thickness = Math.round(dock.iconSize * 1.5);
    var cx = screen.width / 2;
    var cy = screen.height / 2;
    switch (dock.position) {
    case "top":
      cy = thickness;
      break;
    case "bottom":
      cy = screen.height - thickness;
      break;
    case "left":
      cx = thickness;
      break;
    case "right":
      cx = screen.width - thickness;
      break;
    }
    openAt(screen, cx, cy);
  }
}
