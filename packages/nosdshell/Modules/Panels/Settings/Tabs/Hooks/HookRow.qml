import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NDccRow {
  id: root

  property string label: ""
  property string description: ""
  property string value: ""

  signal editClicked

  clickable: true
  onClicked: root.editClicked()

  NLabel {
    label: root.label
    description: root.description
    labelColor: root.value ? Colors.accent : Colors.onShell
    labelWeight: Style.fontWeightRegular
    Layout.fillWidth: true
  }

  NIconButton {
    icon: "settings"
    onClicked: root.editClicked()
    tooltipText: I18n.tr("common.edit")
  }
}
