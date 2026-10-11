import QtQuick
import qs.Commons

// Shared reveal for the visual content of PopupWindow menus (DESIGN §1.7
// motionPopupIn / motionPopupOut): a fade plus, for anchored menus, a
// short slide along the anchor edge — background, shadow and content move
// together. The menu's visual children go inside this item; callers keep
// their own "set _closing, wait motionPopupOut, then visible=false"
// timers so the exit can play before the surface unmaps.
Item {
  id: root

  anchors.fill: parent

  // Surface mapped (the window is visible) / exit in progress.
  property bool active: false
  property bool closing: false
  // Side the anchor is on: "top" | "bottom" | "left" | "right";
  // "" = fade only (submenus, absolute-point menus).
  property string edge: ""

  opacity: active && !closing ? 1.0 : 0.0
  // Content starts shifted toward the anchor and slides to rest on enter;
  // on exit it drifts back toward the anchor.
  property real revealDistance: active && !closing ? 0 : (closing ? Style.popupExitOffset : Style.popupEnterOffset)

  transform: Translate {
    x: root.edge === "left" ? -root.revealDistance : (root.edge === "right" ? root.revealDistance : 0)
    y: root.edge === "top" ? -root.revealDistance : (root.edge === "bottom" ? root.revealDistance : 0)
  }

  // Behaviors stay always enabled: gating enabled on `active` would let
  // the enabled flag and the target value flip in the same binding pass,
  // snapping the open instead of animating it.
  Behavior on opacity {
    NumberAnimation {
      duration: root.closing ? Style.motionPopupOut : Style.motionPopupIn
      easing.type: root.closing ? Easing.InCubic : Easing.OutCubic
    }
  }

  Behavior on revealDistance {
    NumberAnimation {
      duration: root.closing ? Style.motionPopupOut : Style.motionPopupIn
      easing.type: root.closing ? Easing.InCubic : Easing.OutCubic
    }
  }
}
