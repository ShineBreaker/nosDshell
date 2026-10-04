import QtQuick
import QtQuick.Layouts
import qs.Commons

// Section header for DDE dock applet popups (DESIGN §3.2): a tertiary
// section label followed by a 1 px overlay("hover") separator.
ColumnLayout {
  id: root

  property string text: ""

  spacing: 0

  NText {
    text: root.text
    pointSize: Style.fontSizeS
    color: Color.onShellTertiary
    Layout.fillWidth: true
    Layout.leftMargin: Style.marginM
    Layout.bottomMargin: 4
    elide: Text.ElideRight
  }

  Rectangle {
    Layout.fillWidth: true
    height: 1
    color: Color.overlay("hover")
  }
}
