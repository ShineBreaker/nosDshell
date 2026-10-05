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
  NHeader {
    label: I18n.tr("panels.hooks.header")
  }

  // SettingsGroup 1: one DDE SettingsGroup -- rows stack with the
  // 1 px seam of settingsgroup.cpp:46 (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.settingsGroupGap
    NToggle {
      label: I18n.tr("panels.hooks.system-hooks-enable-label")
      description: I18n.tr("panels.hooks.system-hooks-enable-description")
      checked: Settings.data.hooks.enabled
      onToggled: checked => Settings.data.hooks.enabled = checked
    }
  }

  // Info section

  // SettingsGroup gap: 15 px between two groups (DESIGN §3.5.4)
  NDccGap {
    Layout.fillWidth: true
  }
  ColumnLayout {
    spacing: Style.settingsGroupGap
    Layout.fillWidth: true

    NLabel {
      label: I18n.tr("panels.hooks.info-parameters-label")
      description: I18n.tr("panels.hooks.info-parameters-description")
    }
  }
}
