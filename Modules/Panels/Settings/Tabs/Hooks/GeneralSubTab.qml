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
  // SettingsGroup 1: the rows sit flush, the 1 px seam
  // between them comes from the dcc row (DESIGN §3.5.4)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    NToggle {
      label: I18n.tr("panels.hooks.system-hooks-enable-label")
      description: I18n.tr("panels.hooks.system-hooks-enable-description")
      checked: Settings.data.hooks.enabled
      onToggled: checked => Settings.data.hooks.enabled = checked
    }
  }

  // Info section

  // SettingsGroup gap (DESIGN §3.5.4)
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.settingsGroupSpacing ?? 15
  }
  ColumnLayout {
    spacing: 0
    Layout.fillWidth: true

    NLabel {
      label: I18n.tr("panels.hooks.info-parameters-label")
      description: I18n.tr("panels.hooks.info-parameters-description")
    }
  }
}
