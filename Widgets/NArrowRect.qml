import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../Helpers/ArrowRect.js" as ArrowRect

// Rounded rectangle with an optional triangular arrow on one edge
// (DArrowRectangle / DockPopupWindow shape, DESIGN §3.2).
// The item's width x height INCLUDES the arrow; place content inside bodyRect.
Item {
  id: root

  property real radius: Style.radiusPopup
  // "top" | "bottom" | "left" | "right" | "" (no arrow)
  property string arrowEdge: ""
  // Tip coordinate along the edge; negative = centered
  property real arrowPosition: -1
  property real arrowWidth: Style.popupArrowWidth
  property real arrowHeight: Style.popupArrowHeight
  property color fillColor: Color.popupShell
  property color borderColor: Color.borderShell
  property real borderWidth: 1
  // A Style.shadow* object ({blur, x, y, color}) or null
  property var shadow: Style.shadowPopup

  readonly property rect bodyRect: {
    const r = ArrowRect.bodyRect(width, height, arrowEdge, arrowHeight);
    return Qt.rect(r.x, r.y, r.width, r.height);
  }

  NDropShadow {
    anchors.fill: parent
    z: -1
    source: arrowShape
    shadow: root.shadow
    visible: root.shadow !== null && root.shadow !== undefined
    autoPaddingEnabled: true
  }

  Shape {
    id: arrowShape
    anchors.fill: parent
    antialiasing: true

    ShapePath {
      fillColor: root.fillColor
      strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
      strokeWidth: root.borderWidth > 0 ? root.borderWidth : -1
      joinStyle: ShapePath.MiterJoin

      PathSvg {
        path: {
          const pos = root.arrowPosition >= 0 ? root.arrowPosition : (root.arrowEdge === "left" || root.arrowEdge === "right" ? root.height / 2 : root.width / 2);
          return ArrowRect.svgPath(root.width, root.height, root.radius, root.arrowEdge, pos, root.arrowWidth, root.arrowHeight);
        }
      }
    }
  }
}
