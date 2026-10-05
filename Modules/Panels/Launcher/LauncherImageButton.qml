import QtQuick
import QtQuick.Window

import qs.Commons
import qs.Services.UI

// Button that shows the original DDE artwork and swaps normal / hover / press
// images instead of tinting a glyph (DESIGN §1.9: multi-state material is
// switched by state, never simulated with opacity or a filter).
// Source paths are absolute; a "@2x" sibling is preferred on HiDPI screens.
Item {
  id: root

  // Absolute paths, without the "@2x" suffix.
  property string normalSource: ""
  property string hoverSource: ""
  property string pressSource: ""
  // Shown while `checked` is true; falls back to pressSource.
  property string activeSource: ""
  property bool checked: false

  // Set false for artwork without a "@2x" sibling.
  property bool hasRetinaAsset: true

  property real iconSize: width
  property var tooltipText
  property string tooltipDirection: "auto"

  signal clicked

  readonly property bool _retina: hasRetinaAsset && (Screen.devicePixelRatio || 1) > 1
  readonly property string _currentSource: {
    const raw = root.checked ? (root.activeSource !== "" ? root.activeSource : root.pressSource) : (hoverSource !== "" && hoverArea.containsMouse ? (mouseArea.pressed ? root.pressSource : hoverSource) : normalSource);
    if (!root._retina || raw === "")
      return raw;
    const dot = raw.lastIndexOf(".");
    if (dot < 0)
      return raw;
    return raw.slice(0, dot) + "@2x" + raw.slice(dot);
  }

  implicitWidth: iconSize
  implicitHeight: iconSize

  Image {
    id: image
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
    source: root._currentSource
    visible: source !== ""
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
    mipmap: true
    cache: true
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      if (root.tooltipText)
        TooltipService.show(root, root.tooltipText, root.tooltipDirection);
    }
    onExited: {
      if (root.tooltipText)
        TooltipService.hide(root);
    }
    onClicked: {
      if (root.tooltipText)
        TooltipService.hide(root);
      root.clicked();
    }
  }
}
