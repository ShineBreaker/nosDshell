import QtQuick
import qs.Commons

// Shared enter transition for QtQuick.Controls Popup surfaces
// (DESIGN §1.7: motionPopupIn, OutCubic — fade only; unanchored
// surfaces such as dialogs, dropdowns and combo lists carry no slide).
Transition {
  NumberAnimation {
    property: "opacity"
    from: 0.0
    to: 1.0
    duration: Style.motionPopupIn
    easing.type: Easing.OutCubic
  }
}
