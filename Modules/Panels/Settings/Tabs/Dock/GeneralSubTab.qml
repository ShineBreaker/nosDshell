import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "../Shared"

// DDE taskbar "常规" page (DESIGN §3.1.1, §3.5.3): everything that configures
// the dock itself lives under its feature switch — mode/position/size/status,
// then appearance, then window grouping. Disabling the dock hides the whole
// configuration tree below the toggle (a feature switch hides its settings,
// it does not merely grey them out). Fashion-only options hide with the mode
// instead of being labelled "(fashion)".
ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  readonly property bool fashionMode: Settings.data.dock.mode === "fashion"

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.dock.enabled-label")
    description: I18n.tr("panels.dock.enabled-description")
    checked: Settings.data.dock.enabled
    defaultValue: Settings.getDefaultValue("dock.enabled")
    onToggled: checked => Settings.data.dock.enabled = checked
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    visible: Settings.data.dock.enabled

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap

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

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
    }

    // SettingsGroup: dock appearance (fashion/efficient shared keys)
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap
      NHeader {
        label: I18n.tr("settings.advanced.dock-appearance")
      }

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.appearance-background-opacity-label")
        description: I18n.tr("panels.dock.appearance-background-opacity-description")
        from: 0.3
        to: 1
        stepSize: 0.01
        showReset: true
        value: Settings.data.dock.backgroundOpacity
        defaultValue: Settings.getDefaultValue("dock.backgroundOpacity")
        onMoved: value => Settings.data.dock.backgroundOpacity = value
        text: Math.floor(Settings.data.dock.backgroundOpacity * 100) + "%"
      }

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.appearance-dead-opacity-label")
        description: I18n.tr("panels.dock.appearance-dead-opacity-description")
        from: 0
        to: 1
        stepSize: 0.01
        showReset: true
        value: Settings.data.dock.deadOpacity
        defaultValue: Settings.getDefaultValue("dock.deadOpacity")
        onMoved: value => Settings.data.dock.deadOpacity = value
        text: Math.floor(Settings.data.dock.deadOpacity * 100) + "%"
      }

      NValueSlider {
        Layout.fillWidth: true
        visible: root.fashionMode
        label: I18n.tr("panels.dock.appearance-plugin-spacing-label")
        description: I18n.tr("panels.dock.appearance-plugin-spacing-description")
        from: 0
        to: 24
        stepSize: 1
        showReset: true
        value: Settings.data.dock.pluginSpacing
        defaultValue: Settings.getDefaultValue("dock.pluginSpacing")
        onMoved: value => Settings.data.dock.pluginSpacing = value
        text: Math.round(Settings.data.dock.pluginSpacing) + " px"
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.fashionMode
        label: I18n.tr("panels.dock.appearance-fused-plugins-label")
        description: I18n.tr("panels.dock.appearance-fused-plugins-description")
        checked: Settings.data.dock.fusedPlugins
        defaultValue: Settings.getDefaultValue("dock.fusedPlugins")
        onToggled: checked => Settings.data.dock.fusedPlugins = checked
      }

      NToggle {
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.appearance-colorize-icons-label")
        description: I18n.tr("panels.dock.appearance-colorize-icons-description")
        checked: Settings.data.dock.colorizeIcons
        defaultValue: Settings.getDefaultValue("dock.colorizeIcons")
        onToggled: checked => Settings.data.dock.colorizeIcons = checked
      }
    }

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
    }

    // The launcher button icon is its own group — the same group is mounted
    // on the Launcher settings tab (Shared/LauncherIconGroup.qml).
    LauncherIconGroup {
      Layout.fillWidth: true
    }

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
    }

    // SettingsGroup: dock window grouping
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap
      NHeader {
        label: I18n.tr("settings.advanced.dock-grouping")
      }

      NToggle {
        label: I18n.tr("panels.dock.appearance-pinned-static-label")
        description: I18n.tr("panels.dock.appearance-pinned-static-description")
        checked: Settings.data.dock.pinnedStatic
        defaultValue: Settings.getDefaultValue("dock.pinnedStatic")
        onToggled: checked => Settings.data.dock.pinnedStatic = checked
      }

      NToggle {
        label: I18n.tr("panels.dock.appearance-group-apps-label")
        description: I18n.tr("panels.dock.appearance-group-apps-description")
        checked: Settings.data.dock.groupApps
        defaultValue: Settings.getDefaultValue("dock.groupApps")
        onToggled: checked => Settings.data.dock.groupApps = checked
      }

      NComboBox {
        Layout.fillWidth: true
        visible: Settings.data.dock.groupApps
        label: I18n.tr("panels.dock.appearance-group-click-action-label")
        description: I18n.tr("panels.dock.appearance-group-click-action-description")
        model: [
          {
            "key": "cycle",
            "name": I18n.tr("panels.dock.appearance-group-click-action-cycle")
          },
          {
            "key": "list",
            "name": I18n.tr("panels.dock.appearance-group-click-action-list")
          }
        ]
        currentKey: Settings.data.dock.groupClickAction
        defaultValue: Settings.getDefaultValue("dock.groupClickAction")
        onSelected: key => Settings.data.dock.groupClickAction = key
      }

      NComboBox {
        Layout.fillWidth: true
        visible: Settings.data.dock.groupApps
        label: I18n.tr("panels.dock.appearance-group-context-menu-mode-label")
        description: I18n.tr("panels.dock.appearance-group-context-menu-mode-description")
        model: [
          {
            "key": "list",
            "name": I18n.tr("panels.dock.appearance-group-context-menu-mode-list")
          },
          {
            "key": "extended",
            "name": I18n.tr("panels.dock.appearance-group-context-menu-mode-extended")
          }
        ]
        currentKey: Settings.data.dock.groupContextMenuMode
        defaultValue: Settings.getDefaultValue("dock.groupContextMenuMode")
        onSelected: key => Settings.data.dock.groupContextMenuMode = key
      }
    }

    // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
    NDccGap {
      Layout.fillWidth: true
    }

    // SettingsGroup: right-click menu (task-manager command, nosd extension —
    // aligns the menu with the Windows taskbar's Task Manager entry)
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.settingsGroupGap
      NHeader {
        label: I18n.tr("settings.taskbar.menu-group")
      }

      NTextInput {
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.task-manager-command-label")
        description: I18n.tr("panels.dock.task-manager-command-description")
        placeholderText: "btop"
        text: Settings.data.dock.taskManagerCommand
        defaultValue: Settings.getDefaultValue("dock.taskManagerCommand")
        onTextChanged: Settings.data.dock.taskManagerCommand = text
      }
    }
  }
}
