import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Panels & screen corners — DDE has neither; kept as compat on the "面板"
// sub-tab of the stacked 高级 module page (DESIGN §3.5.3).
ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // SettingsGroup: panels & corners (the sub-tab head already names the
  // group, so no inner NHeader).
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.panels-attached-to-bar-label")
      description: I18n.tr("panels.user-interface.panels-attached-to-bar-description")
      checked: Settings.data.ui.panelsAttachedToBar
      defaultValue: Settings.getDefaultValue("ui.panelsAttachedToBar")
      onToggled: checked => Settings.data.ui.panelsAttachedToBar = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.screen-corners-show-corners-label")
      description: I18n.tr("panels.general.screen-corners-show-corners-description")
      checked: Settings.data.general.showScreenCorners
      defaultValue: Settings.getDefaultValue("general.showScreenCorners")
      onToggled: checked => Settings.data.general.showScreenCorners = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.screen-corners-solid-black-label")
      description: I18n.tr("panels.general.screen-corners-solid-black-description")
      checked: Settings.data.general.forceBlackScreenCorners
      defaultValue: Settings.getDefaultValue("general.forceBlackScreenCorners")
      onToggled: checked => Settings.data.general.forceBlackScreenCorners = checked
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.general.screen-corners-radius-label")
      description: I18n.tr("panels.general.screen-corners-radius-description")
      enabled: Settings.data.general.showScreenCorners
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.screenRadiusRatio
      defaultValue: Settings.getDefaultValue("general.screenRadiusRatio")
      onMoved: value => Settings.data.general.screenRadiusRatio = value
      text: Math.floor(Settings.data.general.screenRadiusRatio * 100) + "%"
    }
  }
}
