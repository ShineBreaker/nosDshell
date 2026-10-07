import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

// DDE taskbar "General" page (DESIGN §3.1.1): the five settings of the
// original dock settings menu — enabled, mode, position, size, status.
// All bindings target the live keys (dock.mode / position / iconSize /
// hideMode); see DockSettingsMenu.qml for the menu-side wording.
// The optional status bar group below is a nosd extension (DESIGN §3.13).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.dock.enabled-label")
    description: I18n.tr("panels.dock.enabled-description")
    checked: Settings.data.dock.enabled
    defaultValue: Settings.getDefaultValue("dock.enabled")
    onToggled: checked => Settings.data.dock.enabled = checked
  }

  ColumnLayout {
    spacing: Style.marginL
    enabled: Settings.data.dock.enabled

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("dock-menu.mode")
      description: I18n.tr("settings.taskbar.mode-description")
      model: [
        {
          "key": "fashion",
          "name": I18n.tr("dock-menu.mode-fashion")
        },
        {
          "key": "efficient",
          "name": I18n.tr("dock-menu.mode-efficient")
        }
      ]
      currentKey: Settings.data.dock.mode
      defaultValue: Settings.getDefaultValue("dock.mode")
      onSelected: key => Settings.data.dock.mode = key
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("dock-menu.location")
      model: [
        {
          "key": "top",
          "name": I18n.tr("dock-menu.location-top")
        },
        {
          "key": "bottom",
          "name": I18n.tr("dock-menu.location-bottom")
        },
        {
          "key": "left",
          "name": I18n.tr("dock-menu.location-left")
        },
        {
          "key": "right",
          "name": I18n.tr("dock-menu.location-right")
        }
      ]
      currentKey: Settings.data.dock.position
      defaultValue: Settings.getDefaultValue("dock.position")
      onSelected: key => Settings.data.dock.position = key
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("dock-menu.size")
      description: I18n.tr("settings.taskbar.size-description")
      model: [
        {
          "key": "30",
          "name": I18n.tr("dock-menu.size-small")
        },
        {
          "key": "36",
          "name": I18n.tr("dock-menu.size-medium")
        },
        {
          "key": "48",
          "name": I18n.tr("dock-menu.size-large")
        }
      ]
      currentKey: String(Settings.data.dock.iconSize)
      defaultValue: String(Settings.getDefaultValue("dock.iconSize"))
      onSelected: key => Settings.data.dock.iconSize = parseInt(key)
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("dock-menu.state")
      description: I18n.tr("settings.taskbar.state-description")
      model: [
        {
          "key": "keep-showing",
          "name": I18n.tr("dock-menu.state-keep-showing")
        },
        {
          "key": "keep-hidden",
          "name": I18n.tr("dock-menu.state-keep-hidden")
        },
        {
          "key": "smart-hide",
          "name": I18n.tr("dock-menu.state-smart-hide")
        }
      ]
      currentKey: Settings.data.dock.hideMode
      defaultValue: Settings.getDefaultValue("dock.hideMode")
      onSelected: key => Settings.data.dock.hideMode = key
    }
  }

  // ---- Status bar (DESIGN §3.13) ----
  // macOS-style optional status bar, independent of the dock/taskbar. It only
  // exists in fashion mode — in efficient mode the taskbar already is the bar.
  NHeader {
    label: I18n.tr("settings.taskbar.statusbar")
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("settings.taskbar.statusbar-enabled-label")
      description: I18n.tr("settings.taskbar.statusbar-enabled-description")
      checked: Settings.data.bar.enabled
      defaultValue: Settings.getDefaultValue("bar.enabled")
      onToggled: checked => Settings.data.bar.enabled = checked
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    enabled: Settings.data.bar.enabled && Settings.data.dock.mode === "fashion"

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("settings.taskbar.statusbar-position")
      model: [
        {
          "key": "top",
          "name": I18n.tr("dock-menu.location-top")
        },
        {
          "key": "bottom",
          "name": I18n.tr("dock-menu.location-bottom")
        },
        {
          "key": "left",
          "name": I18n.tr("dock-menu.location-left")
        },
        {
          "key": "right",
          "name": I18n.tr("dock-menu.location-right")
        }
      ]
      currentKey: Settings.data.bar.position
      defaultValue: Settings.getDefaultValue("bar.position")
      onSelected: key => Settings.data.bar.position = key
    }

    NComboBox {
      Layout.fillWidth: true
      label: I18n.tr("settings.taskbar.statusbar-state")
      model: [
        {
          "key": "always_visible",
          "name": I18n.tr("dock-menu.state-keep-showing")
        },
        {
          "key": "auto_hide",
          "name": I18n.tr("dock-menu.state-keep-hidden")
        }
      ]
      currentKey: Settings.data.bar.displayMode
      defaultValue: Settings.getDefaultValue("bar.displayMode")
      onSelected: key => Settings.data.bar.displayMode = key
    }

    NText {
      visible: (Quickshell.screens || []).length > 1
      text: I18n.tr("settings.taskbar.statusbar-monitors")
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Repeater {
      model: (Quickshell.screens || []).length > 1 ? (Quickshell.screens || []) : []
      delegate: NCheckbox {
        Layout.fillWidth: true
        required property var modelData
        readonly property real compositorScale: {
          const info = CompositorService.displayScales[modelData.name];
          return (info && info.scale) ? info.scale : 1.0;
        }
        label: modelData.name || "Unknown"
        description: {
          I18n.tr("system.monitor-description", {
                    "model": modelData.model,
                    "width": modelData.width * compositorScale,
                    "height": modelData.height * compositorScale,
                    "scale": compositorScale
                  });
        }
        checked: (Settings.data.bar.monitors || []).indexOf(modelData.name) !== -1
        onToggled: checked => {
                     var arr = (Settings.data.bar.monitors || []).slice();
                     if (checked) {
                       if (arr.indexOf(modelData.name) === -1)
                       arr.push(modelData.name);
                     } else {
                       arr = arr.filter(function (n) {
                         return n !== modelData.name;
                       });
                     }
                     Settings.data.bar.monitors = arr;
                   }
      }
    }
  }
}
