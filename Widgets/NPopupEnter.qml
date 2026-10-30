import QtQuick
import qs.Commons

// Shared enter transition for QtQuick.Controls Popup surfaces: dialogs,
// dropdown lists, pickers, context menus at the pointer. These have no
// anchor edge, so they grow from their centre (DESIGN §1.7 motionDialogIn:
// opacity, scale dialogEnterScale -> 1 on "out"; ConfirmationDialog.tsx:87-90).
Transition {
  ParallelAnimation {
    NAnim {
      property: "opacity"
      from: 0.0
      to: 1.0
      duration: Style.motionDialogIn
      curve: "out"
    }
    NAnim {
      property: "scale"
      from: Style.dialogEnterScale
      to: 1.0
      duration: Style.motionDialogIn
      curve: "out"
    }
  }
}
