import QtQuick
import "../Helpers/ArrowRect.js" as ArrowRect
import qs.Commons

// Top-edge highlight of dark popups (DESIGN §1.6, cds-theme.css:330): the top
// half of a 1 px ring just inside the outline, i.e. along the top edge and
// round both top corners down to where the sides start. With the arrow on the
// top edge the line breaks at the arrow base.
//
// Plain rounded rectangles clipped to the top band, not a Shape: a stroked
// path whose string follows an animating popup is re-triangulated on every
// frame, and an extra Shape stroke here coincided with lost pointer presses
// on the control centre (see the commit that introduced this file).
//
// Give it the same box (arrow included) as ArrowRect.svgPath; it places
// itself on the body inside that box.
Item {
  id: root

  property real boxWidth: 0
  property real boxHeight: 0
  property real radius: Style.radiusPopup
  // "top" | "bottom" | "left" | "right" | "" (no arrow)
  property string arrowEdge: ""
  // Tip coordinate along the arrow edge, relative to the box
  property real arrowPosition: -1
  property real arrowWidth: Style.popupArrowWidth
  property real arrowHeight: Style.popupArrowHeight
  property color color: Colors.highlightShell

  readonly property var _body: ArrowRect.bodyRect(boxWidth, boxHeight, arrowEdge, arrowHeight)
  readonly property real _r: Math.max(0, Math.min(radius, Math.min(_body.width, _body.height) / 2))
  readonly property bool _gap: arrowEdge === "top" && arrowHeight > 0
  readonly property real _tip: _gap ? ArrowRect._clampTip(arrowPosition >= 0 ? arrowPosition : boxWidth / 2, boxWidth, _r, arrowWidth) : 0
  // [start, end] runs of the line in body x; two around an arrow base
  readonly property var _runs: _gap ? [[0, _tip - arrowWidth / 2], [_tip + arrowWidth / 2, _body.width]] : [[0, _body.width]]

  visible: color.a > 0 && _body.width > 0 && _body.height > 0
  x: _body.x
  y: _body.y
  width: _body.width
  // The band down to where the sides start straightening (y = radius + 1)
  height: Math.ceil(_r) + 2

  Repeater {
    model: root._runs

    delegate: Item {
      required property var modelData
      x: modelData[0]
      width: Math.max(0, modelData[1] - modelData[0])
      height: root.height
      clip: true

      // The ring sits 1 px inside the outline so its 1 px border covers the
      // pixel row (and column) right under the outline stroke; it is taller
      // than the band so only its top arcs show.
      Rectangle {
        x: 1 - parent.x
        y: 1
        width: root.width - 2
        height: root._r * 2 + 4
        radius: Math.max(0, root._r - 1)
        color: "transparent"
        border.color: root.color
        border.width: 1
      }
    }
  }
}
