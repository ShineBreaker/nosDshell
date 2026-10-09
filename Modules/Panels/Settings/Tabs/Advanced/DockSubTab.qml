import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// Advanced taskbar (dock) keys — the "任务栏" sub-tab of the stacked 高级
// module page (DESIGN §3.5.3).
ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  readonly property color launcherPreviewColor: Color.resolveColorKey((Settings.data.dock.launcherIconColor !== undefined) ? Settings.data.dock.launcherIconColor : "none")

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

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.dock.appearance-colorize-icons-label")
      description: I18n.tr("panels.dock.appearance-colorize-icons-description")
      checked: Settings.data.dock.colorizeIcons
      defaultValue: Settings.getDefaultValue("dock.colorizeIcons")
      onToggled: checked => Settings.data.dock.colorizeIcons = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.dock.appearance-launcher-use-distro-logo-label")
      description: I18n.tr("panels.dock.appearance-launcher-use-distro-logo-description")
      checked: Settings.data.dock.launcherUseDistroLogo
      defaultValue: Settings.getDefaultValue("dock.launcherUseDistroLogo")
      onToggled: checked => Settings.data.dock.launcherUseDistroLogo = checked
    }

    NDccRow {
      Layout.fillWidth: true
      interactive: false

      NLabel {
        Layout.fillWidth: true
        label: I18n.tr("panels.dock.appearance-launcher-icon-label")
        description: I18n.tr("panels.dock.appearance-launcher-icon-description")
        labelWeight: Style.fontWeightRegular
      }

      NIconButton {
        visible: !Settings.data.dock.launcherUseDistroLogo
        enabled: !Settings.data.dock.launcherUseDistroLogo
        icon: (Settings.data.dock.launcherIcon && Settings.data.dock.launcherIcon !== "") ? Settings.data.dock.launcherIcon : "search"
        colorFg: root.launcherPreviewColor
        colorFgHover: root.launcherPreviewColor
        tooltipText: I18n.tr("bar.control-center.browse-library")
        onClicked: launcherIconPicker.open()
      }

      Rectangle {
        visible: Settings.data.dock.launcherUseDistroLogo
        width: Style.toOdd(Style.baseWidgetSize * Style.uiScaleRatio)
        height: width
        radius: Math.min(Style.radiusItem, width / 2)
        color: Color.overlay("field")
        border.color: Color.borderShell
        border.width: Style.borderS

        Image {
          anchors.centerIn: parent
          width: parent.width * 0.62
          height: width
          source: HostService.osLogo
          fillMode: Image.PreserveAspectFit
          smooth: true
          asynchronous: true
          layer.enabled: visible
          layer.effect: ShaderEffect {
            property color targetColor: root.launcherPreviewColor
            property real colorizeMode: 2.0

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
          }
        }
      }
    }

    NIconPicker {
      id: launcherIconPicker
      initialIcon: (Settings.data.dock.launcherIcon && Settings.data.dock.launcherIcon !== "") ? Settings.data.dock.launcherIcon : "search"
      onIconSelected: iconName => {
                        Settings.data.dock.launcherIcon = iconName;
                        Settings.saveImmediate();
                      }
    }

    NColorChoice {
      Layout.fillWidth: true
      label: I18n.tr("common.select-icon-color")
      currentKey: Settings.data.dock.launcherIconColor
      defaultValue: Settings.getDefaultValue("dock.launcherIconColor")
      onSelected: key => Settings.data.dock.launcherIconColor = key
    }
  }

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

    NToggle {
      label: I18n.tr("panels.dock.monitors-only-same-monitor-label")
      description: I18n.tr("panels.dock.monitors-only-same-monitor-description")
      checked: Settings.data.dock.onlySameOutput
      defaultValue: Settings.getDefaultValue("dock.onlySameOutput")
      onToggled: checked => Settings.data.dock.onlySameOutput = checked
    }
  }
}
