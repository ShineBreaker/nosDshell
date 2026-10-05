import QtQuick
import Quickshell.Widgets

import qs.Commons
import qs.Widgets
import QtQuick.Layouts

// Non-app result row shared by the fullscreen list and the mini list
// (DESIGN §3.4.1 / §3.4.2): 36 px tall, icon 24 at x=10, text at x=48,
// hover/selection = overlay("hover") rounded rect radiusRow inset 1.
Item {
  id: root

  required property var modelData
  required property int index
  property var listView: null

  signal activated
  signal rightClicked(var mouse)

  width: listView ? listView.width : 400
  height: 36

  readonly property bool selected: listView ? listView.currentIndex === index : false

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 1
    anchors.bottomMargin: 1
    radius: Style.radiusRow
    color: (mouseArea.containsMouse || root.selected) ? Color.overlay("hover") : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }
  }

  // Icon
  IconImage {
    id: rowIcon
    x: 10
    width: 24
    height: 24
    y: 6
    source: modelData.icon ? ThemeIcons.iconFromName(modelData.icon) : ""
    visible: status === Image.Ready
    asynchronous: true
  }

  NIcon {
    x: 10
    y: 6
    width: 24
    height: 24
    pointSize: Style.fontSizeM
    icon: modelData.icon || "search"
    color: Color.onShell
    visible: rowIcon.status !== Image.Ready
  }

  NText {
    x: 48
    width: parent.width - 58
    height: 36
    verticalAlignment: Text.AlignVCenter
    text: modelData.name || ""
    pointSize: Style.fontSizeBody
    color: Color.onShell
    elide: Text.ElideRight
    maximumLineCount: 1
    applyUiScale: false
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
                 if (mouse.button === Qt.RightButton) {
                   root.rightClicked(mouse);
                 } else {
                   root.activated();
                 }
               }
  }
}
