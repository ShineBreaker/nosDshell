import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

  NToggle {
    label: I18n.tr("panels.lock-screen.password-chars-label")
    description: I18n.tr("panels.lock-screen.password-chars-description")
    checked: Settings.data.general.passwordChars
    onToggled: checked => Settings.data.general.passwordChars = checked
    defaultValue: Settings.getDefaultValue("general.passwordChars")
  }

  NToggle {
    label: I18n.tr("panels.lock-screen.enable-lockscreen-media-controls-label")
    description: I18n.tr("panels.lock-screen.enable-lockscreen-media-controls-description")
    checked: Settings.data.general.enableLockScreenMediaControls
    onToggled: checked => Settings.data.general.enableLockScreenMediaControls = checked
    defaultValue: Settings.getDefaultValue("general.enableLockScreenMediaControls")
  }

  NToggle {
    label: I18n.tr("panels.lock-screen.lock-screen-animations-label")
    description: I18n.tr("panels.lock-screen.lock-screen-animations-description")
    checked: Settings.data.general.lockScreenAnimations
    onToggled: checked => Settings.data.general.lockScreenAnimations = checked
    defaultValue: Settings.getDefaultValue("general.lockScreenAnimations")
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.lock-screen.lock-screen-blur-strength-label")
    description: I18n.tr("panels.lock-screen.lock-screen-blur-strength-description")
    from: 0.0
    to: 1.0
    stepSize: 0.01
    showReset: true
    value: Settings.data.general.lockScreenBlur
    onMoved: value => Settings.data.general.lockScreenBlur = value
    text: ((Settings.data.general.lockScreenBlur) * 100).toFixed(0) + "%"
    defaultValue: Settings.getDefaultValue("general.lockScreenBlur")
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.lock-screen.lock-screen-tint-strength-label")
    description: I18n.tr("panels.lock-screen.lock-screen-tint-strength-description")
    from: 0.0
    to: 1.0
    stepSize: 0.01
    showReset: true
    value: Settings.data.general.lockScreenTint
    onMoved: value => Settings.data.general.lockScreenTint = value
    text: ((Settings.data.general.lockScreenTint) * 100).toFixed(0) + "%"
    defaultValue: Settings.getDefaultValue("general.lockScreenTint")
  }
  }

}
