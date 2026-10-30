import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Services.UI
import qs.Widgets

/**
* AllBackgrounds - Unified Shape container for all bar and panel backgrounds
*
* Unified shadow system. This component contains a single Shape
* with multiple ShapePath children (one for bar, one for each panel type).
*
* Benefits:
* - Single GPU-accelerated rendering pass for all backgrounds
* - Unified shadow system (one MultiEffect for everything)
*/
Item {
  id: root
  objectName: "allBackgrounds"

  // Reference Bar
  required property var bar

  // Reference to MainScreen (for panel access)
  required property var windowRoot

  // Panel slots default to the maskShell semantic token (DESIGN §1.2): its
  // alpha is the final alpha, so those panels render via ownBackgroundAlpha
  // outside the effectivePanelOpacity layer. The bar keeps the opaque scheme
  // surface + opacity-layer treatment (efficient mode alone uses maskShell).
  // Efficient (taskbar) mode: the bar gets its own layer so the maskShell
  // alpha isn't double-multiplied by the panel opacity layer
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"

  // Debug access: expose the own-alpha PanelBackground slots so
  // DebugService.dumpBackgroundChain can read assignedPanel/isRenderable
  // without guessing at children[] indices.
  property alias ownAlphaSlot0: ownAlphaSlot0
  property alias ownAlphaSlot1: ownAlphaSlot1
  property alias unifiedSlot0: unifiedSlot0
  property alias unifiedSlot1: unifiedSlot1

  anchors.fill: parent

  // Unified background container
  Item {
    anchors.fill: parent

    // When not using separate bar opacity, use unified approach (original behavior)
    Item {
      anchors.fill: parent
      visible: !Settings.data.bar.useSeparateOpacity && !root.efficientMode

      // Enable layer caching to prevent continuous re-rendering
      layer.enabled: true
      opacity: Style.effectivePanelOpacity

      Shape {
        id: unifiedBackgroundsShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false
        // Gate on the slots so an emptied shape stops painting with the same
        // synchronous update as the panel hide — an asynchronous Shape can
        // otherwise keep compositing its last tessellated geometry (a ghost
        // rect) until a frame the render loop may starve on arrives.
        visible: root.bar !== null || unifiedSlot0.assignedPanel !== null || unifiedSlot1.assignedPanel !== null

        Component.onCompleted: {
          Logger.d("AllBackgrounds", "AllBackgrounds initialized");
        }

        /**
        *  Bar
        */
        BarBackground {
          bar: root.bar
          shapeContainer: unifiedBackgroundsShape
          windowRoot: root.windowRoot
          backgroundColor: Colors.mSurface
        }

        /**
        *  Panel Background Slots
        *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
        */

        // Slot 0: Currently open/opening panel
        PanelBackground {
          id: unifiedSlot0
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            // Only render if this panel belongs to this screen
            return (p && !p.ownBackgroundAlpha && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: Colors.maskShell
        }

        // Slot 1: Closing panel (during transitions)
        PanelBackground {
          id: unifiedSlot1
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            // Only render if this panel belongs to this screen
            return (p && !p.ownBackgroundAlpha && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: Colors.maskShell
        }
      }

      // Apply shadow to the unified backgrounds. A panel may carry its own
      // descriptor (edge sheets use Style.shadowControlCenter, DESIGN §3.5.1);
      // `shadow: null` falls back to the general shadow settings.
      NDropShadow {
        anchors.fill: parent
        source: unifiedBackgroundsShape

        readonly property var shadow: {
          var p = PanelService.backgroundSlotAssignments[0];
          var c = PanelService.backgroundSlotAssignments[1];
          var own = (p && p.screen?.name === root.windowRoot.screen?.name) ? p.panelShadow : undefined;
          if (own === undefined)
            own = (c && c.screen?.name === root.windowRoot.screen?.name) ? c.panelShadow : undefined;
          return own !== undefined ? own : null;
        }
      }
    }

    // When using separate bar opacity (or efficient mode), separate the rendering
    Item {
      anchors.fill: parent
      visible: Settings.data.bar.useSeparateOpacity || root.efficientMode

      // Panel backgrounds with panel opacity
      Item {
        anchors.fill: parent
        // Gate on the slots so an emptied panel background stops painting
        // (shape and shadow together) with the same synchronous update as
        // the panel hide — see the arrow-popup branch note below.
        visible: panelSlot0.assignedPanel !== null || panelSlot1.assignedPanel !== null

        layer.enabled: true
        opacity: Style.effectivePanelOpacity

        Shape {
          id: panelBackgroundsShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false

          /**
          *  Panel Background Slots
          *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
          */

          // Slot 0: Currently open/opening panel
          PanelBackground {
            id: panelSlot0
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[0];
              // Only render if this panel belongs to this screen
              return (p && !p.ownBackgroundAlpha && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: Colors.maskShell
          }

          // Slot 1: Closing panel (during transitions)
          PanelBackground {
            id: panelSlot1
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[1];
              // Only render if this panel belongs to this screen
              return (p && !p.ownBackgroundAlpha && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: Colors.maskShell
          }
        }

        // Apply shadow to the panel backgrounds. A panel may carry its own
        // descriptor (edge sheets use Style.shadowControlCenter, DESIGN
        // §3.5.1) so it gets a dedicated shadow pass, because a MultiEffect
        // shadow applies to the whole source layer.
        NDropShadow {
          anchors.fill: parent
          source: panelBackgroundsShape

          readonly property var shadow: {
            var p = PanelService.backgroundSlotAssignments[0];
            var c = PanelService.backgroundSlotAssignments[1];
            var own = (p && p.screen?.name === root.windowRoot.screen?.name) ? p.panelShadow : undefined;
            if (own === undefined)
              own = (c && c.screen?.name === root.windowRoot.screen?.name) ? c.panelShadow : undefined;
            return own !== undefined ? own : null;
          }
        }
      }

      // Bar background with separate opacity
      Item {
        anchors.fill: parent

        layer.enabled: true
        opacity: root.efficientMode ? 1.0 : Style.effectiveBarOpacity

        Shape {
          id: barBackgroundShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false

          BarBackground {
            bar: root.bar
            shapeContainer: barBackgroundShape
            windowRoot: root.windowRoot
            backgroundColor: root.efficientMode ? Colors.maskShell : Colors.mSurface
          }
        }

        // No shadow on the efficient-mode taskbar (DESIGN §3.1.3)
        NDropShadow {
          anchors.fill: parent
          source: barBackgroundShape
          visible: !root.efficientMode
        }
      }
    }

    // Panels whose background color already carries its final alpha
    // (maskShell-style edge sheets) render outside the effectivePanelOpacity
    // layer — same treatment as the efficient-mode bar, otherwise the alpha
    // would be multiplied twice.
    Item {
      anchors.fill: parent
      visible: ownAlphaSlot0.assignedPanel !== null || ownAlphaSlot1.assignedPanel !== null

      Shape {
        id: ownAlphaPanelShape
        objectName: "ownAlphaPanelShape"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false

        // Slot 0: Currently open/opening panel
        PanelBackground {
          id: ownAlphaSlot0
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            return (p && p.ownBackgroundAlpha && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
          }
          shapeContainer: ownAlphaPanelShape
          defaultBackgroundColor: Colors.maskShell
        }

        // Slot 1: Closing panel (during transitions)
        PanelBackground {
          id: ownAlphaSlot1
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            return (p && p.ownBackgroundAlpha && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
          }
          shapeContainer: ownAlphaPanelShape
          defaultBackgroundColor: Colors.maskShell
        }
      }

      NDropShadow {
        anchors.fill: parent
        source: ownAlphaPanelShape

        readonly property var shadow: {
          var p = PanelService.backgroundSlotAssignments[0];
          var c = PanelService.backgroundSlotAssignments[1];
          var own = (p && p.screen?.name === root.windowRoot.screen?.name) ? p.panelShadow : undefined;
          if (own === undefined)
            own = (c && c.screen?.name === root.windowRoot.screen?.name) ? c.panelShadow : undefined;
          return own !== undefined ? own : null;
        }
      }
    }

    // DDE arrow popups (DESIGN §3.2 DockPopupWindow): rendered outside the
    // panel-opacity layer so the popupShell alpha is not multiplied by
    // Style.effectivePanelOpacity, with their own shadowPopup shadow.
    Item {
      anchors.fill: parent
      // When the last slot detaches, hide the whole branch synchronously
      // with the panel hide. Without the gate, the asynchronous Shape can
      // keep compositing its last tessellated arrow path — a black ghost
      // rect — until a frame the render loop may starve on arrives.
      visible: arrowSlot0.assignedPanel !== null || arrowSlot1.assignedPanel !== null

      // One Shape per slot, faded by item opacity. Baking the panel opacity
      // into the ShapePath colours forced an asynchronous path re-sync on
      // every animation frame, so the body trailed the content: it lingered
      // after the content had faded out (visible in motion.sh close bursts).
      // Item opacity is applied by the scene graph with no re-sync.
      Item {
        id: arrowPopupShape
        anchors.fill: parent

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false
          opacity: arrowSlot0._fade

          // Slot 0: Currently open/opening panel
          ArrowPanelBackground {
            id: arrowSlot0
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[0];
              return (p && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
            }
            shapeContainer: arrowPopupShape
          }
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false
          opacity: arrowSlot1._fade

          // Slot 1: Closing panel (during transitions)
          ArrowPanelBackground {
            id: arrowSlot1
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[1];
              return (p && p.screen?.name === root.windowRoot.screen?.name) ? p : null;
            }
            shapeContainer: arrowPopupShape
          }
        }
      }

      NDropShadow {
        anchors.fill: parent
        source: arrowPopupShape
        shadow: Style.shadowPopup
      }
    }
  }
}
