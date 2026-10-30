import QtQuick
import QtQuick.Shapes
import "../../../Helpers/ArrowRect.js" as ArrowRect
import qs.Commons

/**
* ArrowPanelBackground - PathSvg rendering of DDE arrow popups
*
* Draws the DockPopupWindow shape (DESIGN §3.2): a rounded popupShell rect
* with a triangular arrow on the edge facing the taskbar. Rendered in a
* dedicated Shape (see AllBackgrounds) so the popupShell alpha is not
* multiplied by Style.effectivePanelOpacity and the shadow can use
* Style.shadowPopup.
*
* The panel's body geometry comes from the same panelRegion/panelItem
* placeholder as PanelBackground; the arrow extends the shape on
* assignedPanel.arrowPopupEdge by Style.popupArrowHeight.
*/
ShapePath {
  id: root

  // Dynamically assigned panel (null if slot is unused)
  property var assignedPanel: null

  // Required reference to the parent Shape (for API parity with PanelBackground)
  required property var shapeContainer

  // Get panel's panelRegion (geometry placeholder)
  readonly property var panelRegion: assignedPanel?.panelRegion ?? null

  // Only read geometry while the placeholder is visible
  readonly property var panelBg: (panelRegion && panelRegion.visible) ? panelRegion.panelItem : null

  readonly property real panelX: panelBg ? panelBg.x : 0
  readonly property real panelY: panelBg ? panelBg.y : 0
  readonly property real panelWidth: panelBg ? panelBg.width : 0
  readonly property real panelHeight: panelBg ? panelBg.height : 0

  readonly property string arrowEdge: assignedPanel ? (assignedPanel.arrowPopupEdge || "") : ""
  readonly property real arrowTip: assignedPanel ? (assignedPanel.arrowTipPosition ?? -1) : -1
  readonly property real arrowH: arrowEdge !== "" && arrowTip >= 0 ? Style.popupArrowHeight : 0
  readonly property real arrowW: arrowH > 0 ? Style.popupArrowWidth : 0

  // The drawn box = the body extended by the arrow on the arrow edge
  readonly property real boxX: arrowEdge === "left" ? panelX - arrowH : panelX
  readonly property real boxY: arrowEdge === "top" ? panelY - arrowH : panelY
  readonly property real boxWidth: panelWidth + ((arrowEdge === "left" || arrowEdge === "right") ? arrowH : 0)
  readonly property real boxHeight: panelHeight + ((arrowEdge === "top" || arrowEdge === "bottom") ? arrowH : 0)

  readonly property bool isRenderable: !!(assignedPanel && assignedPanel.useArrowPopup && panelBg && panelWidth > 0 && panelHeight > 0)

  // Body, border and shadow fade with the panel content during the popup
  // reveal (§1.7): the hosting Shape (one per slot, AllBackgrounds) takes
  // this as its item opacity, and NDropShadow samples that Shape, so the
  // shadow follows. The path colours stay constant so a fade never forces
  // an asynchronous path re-sync.
  readonly property real _fade: assignedPanel ? assignedPanel.opacity : 0

  strokeWidth: 1
  strokeColor: isRenderable ? Colors.borderShell : "transparent"
  joinStyle: ShapePath.MiterJoin
  fillColor: isRenderable ? Colors.popupShell : "transparent"

  startX: 0
  startY: 0

  // svgPath emits straight lines for zero radius (no degenerate arcs)
  PathSvg {
    path: root.isRenderable ? ArrowRect.svgPath(root.boxWidth, root.boxHeight, Style.radiusPopup, root.arrowH > 0 ? root.arrowEdge : "", root.arrowTip, root.arrowW, root.arrowH, root.boxX, root.boxY) : ""
  }
}
