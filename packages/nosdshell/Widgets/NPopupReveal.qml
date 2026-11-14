import QtQuick
import qs.Commons

// Shared reveal for the visual content of PopupWindow menus (DESIGN §1.7
// motionPopupIn / motionPopupOut, ClaudeMotionPresets.ts:172-185): the menu
// grows out of its anchor — fade, scale popupEnterScale -> 1 and a short
// slide away from the anchor edge, on the spring-fitted "snappy" curve —
// and leaves faster without overshoot, shrinking to popupExitScale while it
// drifts back. Background, shadow and content move together. The menu's
// visual children go inside this item; callers keep their own "set _closing,
// wait motionPopupOut, then visible=false" timers so the exit can play
// before the surface unmaps.
Item {
  id: root

  anchors.fill: parent
  // Margin between the window edge and the visual body: the host window
  // keeps it free for the shadow (DESIGN §1.6, Style.popupShadowInset).
  property int inset: 0
  anchors.margins: inset

  // Surface mapped (the window is visible) / exit in progress.
  property bool active: false
  property bool closing: false
  // Side the anchor is on: "top" | "bottom" | "left" | "right";
  // "" = no anchor edge (submenus, absolute-point menus): fade and scale
  // from the centre only.
  property string edge: ""

  readonly property bool _shown: active && !closing

  opacity: _shown ? 1.0 : 0.0
  scale: _shown ? 1.0 : (closing ? Style.popupExitScale : Style.popupEnterScale)
  // The scale grows out of the anchor side, so the menu stays attached to
  // the button that opened it.
  transformOrigin: edge === "top" ? Item.Top : edge === "bottom" ? Item.Bottom : edge === "left" ? Item.Left : edge === "right" ? Item.Right : Item.Center
  // Content starts shifted toward the anchor and slides to rest on enter;
  // on exit it drifts back toward the anchor.
  property real revealDistance: _shown ? 0 : (closing ? Style.popupExitOffset : Style.popupEnterOffset)

  transform: Translate {
    x: root.edge === "left" ? -root.revealDistance : (root.edge === "right" ? root.revealDistance : 0)
    y: root.edge === "top" ? -root.revealDistance : (root.edge === "bottom" ? root.revealDistance : 0)
  }

  // Behaviors stay always enabled: gating enabled on `active` would let
  // the enabled flag and the target value flip in the same binding pass,
  // snapping the open instead of animating it.
  Behavior on opacity {
    NAnim {
      duration: root.closing ? Style.motionPopupOut : Style.motionPopupIn
      curve: root.closing ? "cssEaseOut" : "snappy"
    }
  }

  Behavior on scale {
    NAnim {
      duration: root.closing ? Style.motionPopupOut : Style.motionPopupIn
      curve: root.closing ? "cssEaseOut" : "snappy"
    }
  }

  Behavior on revealDistance {
    NAnim {
      duration: root.closing ? Style.motionPopupOut : Style.motionPopupIn
      curve: root.closing ? "cssEaseOut" : "snappy"
    }
  }
}
