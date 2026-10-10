import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

// Right-bar row of the mini launcher (DESIGN §3.4.2, gxde-launcher
// miniframebutton.cpp + skin/qss/miniframe.qss `#MiniFrameButton`): a 30 px row
// holding a 24 px icon and a 14 px label, white text, 6 px left padding, and a
// white 0.1 rounded-4 background while hovered or keyboard-selected. Pressed
// text turns accent (#2ca7f8 upstream, Color.accent here).
Item {
  id: root

  property string text: ""
  // Glyph name (Tabler) or an absolute artwork path in iconSource; the original
  // DDE artwork wins when set (DESIGN §1.9).
  property string icon: ""
  property string iconSource: ""
  // Monochrome artwork is repainted in iconColor so baked-white DDE glyphs
  // follow the panel foreground; set false for multicolor assets.
  property bool recolorIcon: true
  property color iconColor: Color.onShell
  property int iconSize: 24
  property bool selected: false
  property real rowHeight: Style.launcherMiniButtonRowHeight

  signal clicked
  signal hovered

  implicitHeight: rowHeight
  implicitWidth: rowContent.implicitWidth + Style.marginS + Style.marginS

  readonly property bool _active: hoverArea.containsMouse || selected

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusRow
    color: root._active ? Color.overlay("hover") : "transparent"
  }

  RowLayout {
    id: rowContent
    anchors.fill: parent
    anchors.leftMargin: Style.marginS
    anchors.rightMargin: Style.marginS
    spacing: Style.marginS

    NSymbolicImage {
      visible: root.iconSource !== ""
      Layout.preferredWidth: root.iconSize
      Layout.preferredHeight: root.iconSize
      source: root.iconSource
      symbolic: root.recolorIcon
      color: root.iconColor
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
    }

    NIcon {
      visible: root.iconSource === "" && root.icon !== ""
      Layout.preferredWidth: root.iconSize
      Layout.preferredHeight: root.iconSize
      Layout.alignment: Qt.AlignVCenter
      icon: root.icon
      // iconSize is in logical px; 96 dpi means 1 px == 0.75 pt
      pointSize: root.iconSize * 0.75
      color: Color.onShell
    }

    NText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: root.text
      pointSize: Style.launcherMiniButtonFontSize
      font.weight: Style.fontWeightMedium
      color: mouseArea.pressed ? Color.accent : Color.onShell
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignLeft
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: root.hovered()
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
