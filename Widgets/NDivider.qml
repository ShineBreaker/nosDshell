import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

Rectangle {
  property bool vertical: false

  width: vertical ? Style.borderS : parent.width
  height: vertical ? parent.height : Style.borderS
  gradient: Gradient {
    orientation: vertical ? Gradient.Vertical : Gradient.Horizontal
    GradientStop {
      position: 0.0
      color: "transparent"
    }
    GradientStop {
      position: 0.1
      color: Color.overlay("field")
    }
    GradientStop {
      position: 0.9
      color: Color.overlay("field")
    }
    GradientStop {
      position: 1.0
      color: "transparent"
    }
  }
}
