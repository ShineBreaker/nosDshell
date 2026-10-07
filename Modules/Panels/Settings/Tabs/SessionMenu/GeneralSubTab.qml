import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.show-keybinds-label")
    description: I18n.tr("panels.session-menu.show-keybinds-description")
    checked: Settings.data.sessionMenu.showKeybinds
    onToggled: checked => Settings.data.sessionMenu.showKeybinds = checked
    defaultValue: Settings.getDefaultValue("sessionMenu.showKeybinds")
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.enable-countdown-label")
    description: I18n.tr("panels.session-menu.enable-countdown-description")
    checked: Settings.data.sessionMenu.enableCountdown
    onToggled: checked => Settings.data.sessionMenu.enableCountdown = checked
    defaultValue: Settings.getDefaultValue("sessionMenu.enableCountdown")
  }

  NValueSlider {
    visible: Settings.data.sessionMenu.enableCountdown
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.countdown-duration-label")
    description: I18n.tr("panels.session-menu.countdown-duration-description")
    from: 1000
    to: 30000
    stepSize: 1000
    showReset: true
    value: Settings.data.sessionMenu.countdownDuration
    onMoved: value => Settings.data.sessionMenu.countdownDuration = value
    text: Math.round(Settings.data.sessionMenu.countdownDuration / 1000) + "s"
    defaultValue: Settings.getDefaultValue("sessionMenu.countdownDuration")
  }
  }

}
