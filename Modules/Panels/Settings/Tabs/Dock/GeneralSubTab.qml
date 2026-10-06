import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// DDE taskbar "General" page (DESIGN §3.1.1): the five settings of the
// original dock settings menu — enabled, mode, position, size, status.
// All bindings target the live keys (dock.mode / position / iconSize /
// hideMode); see DockSettingsMenu.qml for the menu-side wording.
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
}
