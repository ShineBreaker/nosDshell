import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap

  NToggle {
    label: I18n.tr("panels.lock-screen.lock-on-suspend-label")
    description: I18n.tr("panels.lock-screen.lock-on-suspend-description")
    checked: Settings.data.general.lockOnSuspend
    onToggled: checked => Settings.data.general.lockOnSuspend = checked
    defaultValue: Settings.getDefaultValue("general.lockOnSuspend")
  }

  NToggle {
    label: I18n.tr("panels.lock-screen.auto-start-auth-label")
    description: I18n.tr("panels.lock-screen.auto-start-auth-description")
    checked: Settings.data.general.autoStartAuth
    onToggled: checked => Settings.data.general.autoStartAuth = checked
    defaultValue: Settings.getDefaultValue("general.autoStartAuth")
  }

  NToggle {
    label: I18n.tr("panels.lock-screen.allow-password-with-fprintd-label")
    description: I18n.tr("panels.lock-screen.allow-password-with-fprintd-description")
    checked: Settings.data.general.allowPasswordWithFprintd
    onToggled: checked => Settings.data.general.allowPasswordWithFprintd = checked
    defaultValue: Settings.getDefaultValue("general.allowPasswordWithFprintd")
  }

  NToggle {
    label: I18n.tr("panels.session-menu.enable-countdown-label")
    description: I18n.tr("panels.session-menu.enable-countdown-description")
    checked: Settings.data.general.enableLockScreenCountdown
    onToggled: checked => Settings.data.general.enableLockScreenCountdown = checked
    defaultValue: Settings.getDefaultValue("general.enableLockScreenCountdown")
  }

  NValueSlider {
    visible: Settings.data.general.enableLockScreenCountdown
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.countdown-duration-label")
    description: I18n.tr("panels.session-menu.countdown-duration-description")
    from: 1000
    to: 30000
    stepSize: 1000
    showReset: true
    value: Settings.data.general.lockScreenCountdownDuration
    onMoved: value => Settings.data.general.lockScreenCountdownDuration = value
    text: Math.round(Settings.data.general.lockScreenCountdownDuration / 1000) + "s"
    defaultValue: Settings.getDefaultValue("general.lockScreenCountdownDuration")
  }
  }

}
