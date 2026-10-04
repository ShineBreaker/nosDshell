import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

// DDE OptionItem: whole row clickable, checked = accent check glyph on the
// right, unchecked = nothing; hover shows a subtle row background (DESIGN §3.5.4).
Item {
  id: root

  // Public API
  property string label: ""
  property string description: ""
  property bool checked: false
  property bool hovering: false
  property color activeColor: Color.accent
  property color activeOnColor: "#FFFFFF"
  property int baseSize: root.defaultSize
  property real labelSize: Style.fontSizeL

  readonly property int defaultSize: Style.baseWidgetSize * 0.7

  signal toggled(bool checked)
  signal entered
  signal exited

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusRow
    color: root.hovering ? Color.overlay("hover") : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }
  }

  RowLayout {
    id: row
    anchors.left: parent.left
    anchors.right: parent.right

    NLabel {
      label: root.label
      labelSize: root.labelSize
      description: root.description
      visible: root.label !== "" || root.description !== ""
      Layout.fillWidth: true
    }

    // Spacer to push the check to the far right
    Item {
      Layout.fillWidth: true
    }

    NIcon {
      visible: root.checked
      icon: "check"
      color: root.activeColor
      pointSize: Style.toOdd(root.baseSize * 0.5)
      opacity: enabled ? 1.0 : 0.6
      Layout.margins: Style.borderS
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    hoverEnabled: true
    enabled: root.enabled
    onEntered: {
      hovering = true;
      root.entered();
    }
    onExited: {
      hovering = false;
      root.exited();
    }
    onClicked: root.toggled(!root.checked)
  }
}
