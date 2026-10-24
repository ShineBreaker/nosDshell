import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// One DDE SettingsGroup holding the launcher button's icon controls —
// shared by the Dock and Launcher settings tabs so the dock.launcher* keys
// have exactly one implementation while staying discoverable from both
// places users look. Size 0 = derive per mode (efficient 16px glyph,
// fashion follows dock.iconSize); the slider's reset returns to auto.
ColumnLayout {
  id: root

  Layout.fillWidth: true
  spacing: Style.settingsGroupGap

  readonly property color launcherPreviewColor: Colors.resolveColorKey((Settings.data.dock.launcherIconColor !== undefined) ? Settings.data.dock.launcherIconColor : "none")
  readonly property bool fashionMode: Settings.data.dock.mode === "fashion"

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
      color: Colors.overlay("field")
      border.color: Colors.borderShell
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

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.dock.appearance-launcher-icon-size-label")
    description: I18n.tr("panels.dock.appearance-launcher-icon-size-description")
    from: 12
    to: 48
    stepSize: 1
    showReset: true
    value: Settings.data.dock.launcherIconSize
    defaultValue: Settings.getDefaultValue("dock.launcherIconSize")
    onMoved: value => Settings.data.dock.launcherIconSize = Math.round(value)
    text: Settings.data.dock.launcherIconSize > 0 ? Math.round(Settings.data.dock.launcherIconSize) + " px" : I18n.tr("common.auto")
  }
}
