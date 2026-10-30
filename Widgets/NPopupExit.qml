import QtQuick
import qs.Commons

// Shared exit transition for QtQuick.Controls Popup surfaces (DESIGN §1.7
// motionDialogOut: shorter than the enter, no overshoot; the surface shrinks
// back toward dialogEnterScale while it fades).
Transition {
  ParallelAnimation {
    NAnim {
      property: "opacity"
      from: 1.0
      to: 0.0
      duration: Style.motionDialogOut
      curve: "out"
    }
    NAnim {
      property: "scale"
      from: 1.0
      to: Style.dialogEnterScale
      duration: Style.motionDialogOut
      curve: "out"
    }
  }
}
