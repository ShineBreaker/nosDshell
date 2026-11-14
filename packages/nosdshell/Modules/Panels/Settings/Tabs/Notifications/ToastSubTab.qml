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
  NSettingsGroup {
    Layout.fillWidth: true
    visible: Settings.data.notifications.enabled

    NCheckbox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-media-label")
      checked: Settings.data.notifications.enableMediaToast
      onToggled: checked => Settings.data.notifications.enableMediaToast = checked
    }

    NCheckbox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-keyboard-label")
      checked: Settings.data.notifications.enableKeyboardLayoutToast
      onToggled: checked => Settings.data.notifications.enableKeyboardLayoutToast = checked
    }

    NCheckbox {
      Layout.fillWidth: true
      label: I18n.tr("panels.notifications.toast-battery-label")
      checked: Settings.data.notifications.enableBatteryToast
      onToggled: checked => Settings.data.notifications.enableBatteryToast = checked
    }
  }
}
