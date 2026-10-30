import QtQuick
import QtQuick.Shapes
import "../Helpers/ArrowRect.js" as ArrowRect
import qs.Commons

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
  property color fillColor: Colors.popupShell
  property color borderColor: Colors.borderShell
  property real borderWidth: 1
  // Top-edge highlight of dark popups (DESIGN §1.6); transparent in light mode
  property color highlightColor: Colors.highlightShell
  // A Style.shadow* object ({blur, x, y, color}) or null
  property var shadow: Style.shadowPopup

  readonly property real _tipPos: arrowPosition >= 0 ? arrowPosition : (arrowEdge === "left" || arrowEdge === "right" ? height / 2 : width / 2)

  readonly property rect bodyRect: {
    const r = ArrowRect.bodyRect(width, height, arrowEdge, arrowHeight);
    return Qt.rect(r.x, r.y, r.width, r.height);
  }

  // The opaque body as a trackable item — PopupWindow consumers publish it
  // as their ext-background-effect blur region (via NSurfaceRegion). niri's
  // `popups { blur true }` rule blurs the whole surface rect otherwise, and
  // the arrow's transparent margins then show the blurred backdrop as a
  // stray band beside/below the card.
  readonly property Item bodyItem: bodyArea

  Item {
    id: bodyArea
    x: root.bodyRect.x
    y: root.bodyRect.y
    width: root.bodyRect.width
    height: root.bodyRect.height
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
        path: ArrowRect.svgPath(root.width, root.height, root.radius, root.arrowEdge, root._tipPos, root.arrowWidth, root.arrowHeight)
      }
    }
  }

  NTopHighlight {
    boxWidth: root.width
    boxHeight: root.height
    radius: root.radius
    arrowEdge: root.arrowEdge
    arrowPosition: root._tipPos
    arrowWidth: root.arrowWidth
    arrowHeight: root.arrowHeight
    color: root.highlightColor
  }
}
