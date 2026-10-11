import QtQuick
import qs.Commons

// Shared exit transition for QtQuick.Controls Popup surfaces
// (DESIGN §1.7: motionPopupOut, InCubic — fade only).
Transition {
  NumberAnimation {
    property: "opacity"
    from: 1.0
    to: 0.0
    duration: Style.motionPopupOut
    easing.type: Easing.InCubic
  }
}
