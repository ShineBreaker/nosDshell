import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

Rectangle {
  id: root

  // "fade" (default): single line fading at both ends.
  // "ddeGroove": DDE menu separator (§3.3) — a 1 px dark leg over a 1 px
  // light leg, always horizontal, 2 px tall.
  property bool vertical: false
  property string variant: "fade"

  width: vertical ? Style.borderS : parent.width
  height: vertical ? parent.height : (variant === "ddeGroove" ? 2 * Style.borderS : Style.borderS)
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    visible: root.variant === "fade"
    gradient: Gradient {
      orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
      GradientStop {
        position: 0.0
        color: "transparent"
      }
      GradientStop {
        position: 0.1
        color: Colors.overlay("field")
      }
      GradientStop {
        position: 0.9
        color: Colors.overlay("field")
      }
      GradientStop {
        position: 1.0
        color: "transparent"
      }
    }
  }

  Rectangle {
    visible: root.variant === "ddeGroove"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Style.borderS
    color: Colors.grooveShadow
  }

  Rectangle {
    visible: root.variant === "ddeGroove"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Style.borderS
    height: Style.borderS
    color: Colors.grooveLine
  }
}
