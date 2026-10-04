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

  // Reference Bar
  required property var bar

  // Reference to MainScreen (for panel access)
  required property var windowRoot

  readonly property color panelBackgroundColor: Color.mSurface
  // Efficient (taskbar) mode: the bar gets its own layer so the maskShell
  // alpha isn't double-multiplied by the panel opacity layer
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"

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
          backgroundColor: panelBackgroundColor
        }

        /**
        *  Panel Background Slots
        *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
        */

        // Slot 0: Currently open/opening panel
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            // Only render if this panel belongs to this screen
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: panelBackgroundColor
        }

        // Slot 1: Closing panel (during transitions)
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            // Only render if this panel belongs to this screen
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: panelBackgroundColor
        }
      }

      // Apply shadow to the unified backgrounds
      NDropShadow {
        anchors.fill: parent
        source: unifiedBackgroundsShape
      }
    }

    // When using separate bar opacity (or efficient mode), separate the rendering
    Item {
      anchors.fill: parent
      visible: Settings.data.bar.useSeparateOpacity || root.efficientMode

      // Panel backgrounds with panel opacity
      Item {
        anchors.fill: parent

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
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[0];
              // Only render if this panel belongs to this screen
              return (p && p.screen === root.windowRoot.screen) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: panelBackgroundColor
          }

          // Slot 1: Closing panel (during transitions)
          PanelBackground {
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[1];
              // Only render if this panel belongs to this screen
              return (p && p.screen === root.windowRoot.screen) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: panelBackgroundColor
          }
        }

        // Apply shadow to the panel backgrounds
        NDropShadow {
          anchors.fill: parent
          source: panelBackgroundsShape
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
            backgroundColor: root.efficientMode ? Color.maskShell : panelBackgroundColor
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
  }
}
