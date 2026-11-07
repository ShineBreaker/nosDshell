import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0
  width: parent.width

  // Enable/Disable Toggle
  // Section head: this sub-tab used to be an NTabButton (DESIGN §3.5.3)
  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  NSettingsGroup {
    Layout.fillWidth: true
    NToggle {
      label: I18n.tr("panels.hooks.system-hooks-enable-label")
      checked: Settings.data.hooks.enabled
      onToggled: checked => Settings.data.hooks.enabled = checked
    }
  }
}
