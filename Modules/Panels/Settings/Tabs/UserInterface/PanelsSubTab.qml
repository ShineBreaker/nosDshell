import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      visible: (Quickshell.screens.length > 1)
      label: I18n.tr("panels.user-interface.allow-panels-without-bar-label")
      description: I18n.tr("panels.user-interface.allow-panels-without-bar-description")
      checked: Settings.data.general.allowPanelsOnScreenWithoutBar
      defaultValue: Settings.getDefaultValue("general.allowPanelsOnScreenWithoutBar")
      onToggled: checked => Settings.data.general.allowPanelsOnScreenWithoutBar = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.panel-background-opacity-label")
      description: I18n.tr("panels.user-interface.panel-background-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.panelBackgroundOpacity
      defaultValue: Settings.getDefaultValue("ui.panelBackgroundOpacity")
      onMoved: value => Settings.data.ui.panelBackgroundOpacity = value
      text: Math.floor(Settings.data.ui.panelBackgroundOpacity * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.dimmer-opacity-label")
      description: I18n.tr("panels.user-interface.dimmer-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.dimmerOpacity
      defaultValue: Settings.getDefaultValue("general.dimmerOpacity")
      onMoved: value => Settings.data.general.dimmerOpacity = value
      text: Math.floor(Settings.data.general.dimmerOpacity * 100) + "%"
    }
  }
}
