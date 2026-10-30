import QtQuick
import qs.Commons

// Press feedback for button-class controls (DESIGN §0 principle 6, §1.11;
// open-claude-ui cds-theme.css:482-491 .cds-btn-squish): while pressed the
// control shrinks to Style.pressScale on motionPress ("cssEaseOut"); on
// release it springs back to 1 on motionRelease ("release", ~9 %
// overshoot). Bind the visual's scale to `value`:
//
//   NPressScale { id: press; pressed: mouseArea.pressed && root.enabled }
//   Rectangle { scale: press.value; ... }
//
// Row-class elements (menu rows, list rows, grid cells, settings rows)
// never use it. Under reduced motion the control keeps its size.
Item {
  id: root

  property bool pressed: false
  readonly property real value: _value

  property real _value: pressed && !Style.reduceMotion ? Style.pressScale : 1.0

  visible: false

  Behavior on _value {
    NAnim {
      duration: root.pressed ? Style.motionPress : Style.motionRelease
      curve: root.pressed ? "cssEaseOut" : "release"
    }
  }
}
