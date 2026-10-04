import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// DDE OptionItem radio: no circle; checked shows an accent check glyph on
// the right; the whole row is clickable and highlights on hover (DESIGN §3.5.4).
RadioButton {
  id: root

  property real pointSize: Style.fontSizeM
  // Inset the row content (not the hover background) — used by DDE applet
  // panels which pad rows 10–20 px inside the 36 px row bounds
  property real contentHorizontalPadding: 0

  implicitWidth: contentItem.implicitWidth

  indicator: Item {
    implicitWidth: 0
    implicitHeight: 0
  }

  contentItem: Rectangle {
    implicitWidth: rowContent.implicitWidth
    implicitHeight: rowContent.implicitHeight
    radius: Style.radiusRow
    color: root.hovered ? Color.overlay("hover") : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: root.contentHorizontalPadding
      anchors.rightMargin: root.contentHorizontalPadding
      anchors.verticalCenter: parent.verticalCenter

      NText {
        text: root.text
        pointSize: root.pointSize
        Layout.fillWidth: true
      }

      NIcon {
        icon: "check"
        pointSize: Style.fontSizeXL
        color: Color.accent
        visible: root.checked
      }
    }
  }
}
