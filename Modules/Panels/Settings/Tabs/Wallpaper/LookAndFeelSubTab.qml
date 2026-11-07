import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true
  visible: Settings.data.wallpaper.enabled

  property var screen

  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true
    NComboBox {
      label: I18n.tr("panels.wallpaper.look-feel-fill-mode-label")
      model: WallpaperService.fillModeModel
      currentKey: Settings.data.wallpaper.fillMode
      onSelected: key => Settings.data.wallpaper.fillMode = key
      defaultValue: Settings.getDefaultValue("wallpaper.fillMode")
    }

    NDccRow {
      Layout.fillWidth: true

      NLabel {
        id: fillColorLabel
        label: I18n.tr("bar.audio-visualizer.color-name-label")
        labelWeight: Style.fontWeightRegular
        Layout.fillWidth: true
        Layout.minimumWidth: Math.min(fillColorLabel.labelImplicitWidth, Style.settingsFieldTitleMaxWidth)
      }

      NColorPicker {
        screen: root.screen
        selectedColor: Settings.data.wallpaper.fillColor
        onColorSelected: color => Settings.data.wallpaper.fillColor = color
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: Style.settingsFieldWidth
        Layout.preferredWidth: Style.settingsFieldWidth
        Layout.maximumWidth: Style.settingsFieldWidth
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  NSettingsGroup {
    title: I18n.tr("panels.wallpaper.look-feel-transition-type-label")

    Layout.fillWidth: true

    Repeater {
      model: WallpaperService.allTransitions

      NCheckbox {
        required property string modelData
        label: {
          var key = "wallpaper.transitions." + modelData;
          return I18n.tr(key);
        }
        labelSize: Style.fontSizeM
        checked: Settings.data.wallpaper.transitionType.includes(modelData)
        onToggled: checked => {
          var arr = Array.from(Settings.data.wallpaper.transitionType);
          if (checked) {
            if (!arr.includes(modelData))
              arr.push(modelData);
          } else {
            arr = arr.filter(k => k !== modelData);
          }
          Settings.data.wallpaper.transitionType = arr;
        }
      }
    }
  }

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  // SettingsGroup 3: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true
    NToggle {
      label: I18n.tr("panels.wallpaper.look-feel-skip-startup-transition-label")
      checked: Settings.data.wallpaper.skipStartupTransition
      onToggled: Settings.data.wallpaper.skipStartupTransition = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.wallpaper.look-feel-transition-duration-label")
      from: 500
      to: 10000
      stepSize: 100
      showReset: true
      value: Settings.data.wallpaper.transitionDuration
      onMoved: value => Settings.data.wallpaper.transitionDuration = value
      text: (Settings.data.wallpaper.transitionDuration / 1000).toFixed(1) + "s"
      defaultValue: Settings.getDefaultValue("wallpaper.transitionDuration")
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.wallpaper.look-feel-edge-smoothness-label")
      from: 0.0
      to: 1.0
      showReset: true
      value: Settings.data.wallpaper.transitionEdgeSmoothness
      onMoved: value => Settings.data.wallpaper.transitionEdgeSmoothness = value
      text: Math.round(Settings.data.wallpaper.transitionEdgeSmoothness * 100) + "%"
      defaultValue: Settings.getDefaultValue("wallpaper.transitionEdgeSmoothness")
    }
  }
}
