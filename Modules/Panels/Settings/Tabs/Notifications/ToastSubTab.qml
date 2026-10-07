import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  Layout.fillWidth: true

  // Toast popups are notification output too — dim them with the master switch.
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    enabled: Settings.data.notifications.enabled

    NCheckbox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-media-label")
      description: I18n.tr("panels.notifications.toast-media-description")
      checked: Settings.data.notifications.enableMediaToast
      onToggled: checked => Settings.data.notifications.enableMediaToast = checked
    }

    NCheckbox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-keyboard-label")
      description: I18n.tr("panels.notifications.toast-keyboard-description")
      checked: Settings.data.notifications.enableKeyboardLayoutToast
      onToggled: checked => Settings.data.notifications.enableKeyboardLayoutToast = checked
    }

    NCheckbox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-battery-label")
      description: I18n.tr("panels.notifications.toast-battery-description")
      checked: Settings.data.notifications.enableBatteryToast
      onToggled: checked => Settings.data.notifications.enableBatteryToast = checked
    }
  }
}
