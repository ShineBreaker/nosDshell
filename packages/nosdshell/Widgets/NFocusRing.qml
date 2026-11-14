import QtQuick
import qs.Commons

// Keyboard focus ring (DESIGN §1.11; open-claude-ui cds-theme.css:130,339
// --cds-focus-shadow, with the DDE accent in place of clay): a 1.5 px accent
// ring 1 px outside the control, plus a soft accent halo beyond it.
// Show it for keyboard focus only; pointer focus draws nothing.
//
//   NFocusRing { anchors.fill: card; radius: card.radius; shown: card.keyboardFocused }
//
// Declare it as a sibling after the control (or as its last child) so it
// draws on top; it takes no input. Inside a clipping view where the control
// spans the full width, set `outside: false`: the ring then sits on the
// control's edge and the halo is dropped, so nothing is cut off.
Item {
  id: root

  property bool shown: false
  // Corner radius of the control the ring follows.
  property real radius: 0
  property bool outside: true

  readonly property real _gap: outside ? 1 : -1.5
  readonly property real _ring: 1.5
  readonly property real _halo: outside ? (Colors.shellIsDark ? 4 : 3) : 0

  opacity: shown ? 1 : 0
  visible: opacity > 0
  enabled: false

  Behavior on opacity {
    NAnim {
      duration: Style.motionFocus
      curve: "cssEaseOut"
    }
  }

  // Halo: a wider, faint band outside the ring.
  Rectangle {
    visible: root._halo > 0
    anchors.fill: parent
    anchors.margins: -(root._gap + root._ring + root._halo)
    radius: root.radius + root._gap + root._ring + root._halo
    color: "transparent"
    border.width: root._halo
    border.color: Qt.alpha(Colors.accent, Colors.shellIsDark ? 0.35 : 0.25)
  }

  // Ring
  Rectangle {
    anchors.fill: parent
    anchors.margins: -(root._gap + root._ring)
    radius: root.radius + root._gap + root._ring
    color: "transparent"
    border.width: root._ring
    border.color: Colors.accent
  }
}
