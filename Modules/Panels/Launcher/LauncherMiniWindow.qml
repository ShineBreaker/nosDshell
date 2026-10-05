import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.Commons
import qs.Services.UI
import qs.Widgets

// Mini launcher window (DESIGN §3.4.2): a small floating panel 1 px from the
// taskbar. Fashion mode aligns the window with the dock's start edge on the
// inner side; efficient mode puts it in the screen corner next to the launcher
// button. Opening animation: fade + 8 px slide from the taskbar side.
Variants {
  id: root

  model: Quickshell.screens

  // The Loader is the delegate itself (mirrors OSD's structure): a wrapping
  // Item stays unsized and never creates its children.
  delegate: Loader {
    id: screenItem

    required property ShellScreen modelData

    active: true
    asynchronous: false

    // The layer surface exists for the whole session; LauncherState decides
    // whether it shows and takes keyboard focus.
    readonly property bool isActive: modelData !== null && LauncherState.miniOpen && LauncherState.miniScreen === modelData

    // -----------------------------------------------------------
    // Geometry (gxde-launcher windowedframe.cpp adjustPosition)
    // -----------------------------------------------------------
    readonly property string barPosition: Settings.getBarPositionForScreen(modelData?.name ?? "")
    readonly property bool efficient: Settings.data.dock.mode === "efficient"
    readonly property bool hasTaskbar: BarService.hasTaskbarOnScreen(modelData?.name ?? "")

    readonly property real windowWidth: Style.launcherMiniLeftPaneWidth + Style.launcherMiniRightPaneWidth
    readonly property real windowHeight: Style.launcherMiniHeight
    // 1 px off the taskbar (windowedframe.cpp adjustPosition)
    readonly property real gap: Style.launcherMiniDockGap

    // Cross-axis thickness of the taskbar: the efficient bar's height, or the
    // fashion dock's item box. DDE reads this straight off dockRect.
    readonly property real barThickness: hasTaskbar ? (efficient ? Style.barHeight : Style.dockItemThickness) : 0

    // Long-axis length of the centred fashion dock, published by DockContent.
    // Bound through dockLengthsRevision so the position follows the dock as
    // items come and go.
    readonly property real dockLength: {
      BarService.dockLengthsRevision;
      return efficient ? 0 : BarService.getDockLength(modelData?.name ?? "");
    }

    // Efficient mode: the screen corner next to the launcher button, because the
    // dock fills the whole edge there (windowedframe.cpp:757-772).
    readonly property real cornerX: {
      switch (barPosition) {
      case "left":
        return barThickness + gap;
      case "right":
        return (modelData?.width ?? 0) - barThickness - gap - windowWidth;
      default:
        return gap;
      }
    }

    readonly property real cornerY: {
      switch (barPosition) {
      case "top":
        return barThickness + gap;
      case "bottom":
        return (modelData?.height ?? 0) - barThickness - gap - windowHeight;
      default:
        return gap;
      }
    }

    // Fashion mode: line the window up with the dock's start edge on the long
    // axis and sit flush against the dock on the short one
    // (windowedframe.cpp:773-789 — p.x / p.y come from dockRect).
    readonly property real fashionX: {
      const screenW = modelData?.width ?? 0;
      switch (barPosition) {
      case "left":
        return barThickness + gap;
      case "right":
        return screenW - barThickness - gap - windowWidth;
      default:
        return Math.max(gap, Math.round((screenW - dockLength) / 2));
      }
    }

    readonly property real fashionY: {
      const screenH = modelData?.height ?? 0;
      switch (barPosition) {
      case "top":
        return barThickness + gap;
      case "bottom":
        return screenH - barThickness - gap - windowHeight;
      default:
        return Math.max(gap, Math.round((screenH - dockLength) / 2));
      }
    }

    sourceComponent: PanelWindow {
      id: window

      screen: screenItem.modelData
      visible: screenItem.isActive
      color: "transparent"
      // The right bar widens itself until the settings + power row fits, so the
      // window follows the view rather than the other way round
      // (LauncherMiniView.measuredRightPaneWidth, miniframerightbar.cpp updateSize()).
      implicitWidth: view.implicitWidth
      implicitHeight: screenItem.windowHeight

      WlrLayershell.namespace: "nosd-launcher-mini-" + (screen?.name || "unknown")
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: screenItem.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      anchors {
        left: true
        top: true
      }

      margins.left: screenItem.efficient ? screenItem.cornerX : screenItem.fashionX
      margins.top: screenItem.efficient ? screenItem.cornerY : screenItem.fashionY

      // The panel surface: maskShell, 1 px overlay("hover") border,
      // radius radiusItem.
      // ponytail: per-corner radius (radiusLarge on the taskbar-side corner in
      // efficient mode) would need a Canvas or a mask image; QML Rectangle
      // only supports a uniform radius. Upgrade if the corner becomes
      // visually load-bearing.
      Rectangle {
        id: panelBg
        anchors.fill: parent
        color: Color.maskShell
        radius: Style.radiusItem
        border.width: Style.borderM
        border.color: Color.overlay("hover")
      }

      // Opening animation: fade + 8 px slide from the taskbar side.
      // The slide is applied to the content item, so the window keeps its
      // anchored geometry.
      LauncherMiniView {
        id: view

        anchors.fill: parent
        screen: screenItem.modelData
        barPosition: screenItem.barPosition

        enabled: screenItem.isActive
        opacity: screenItem.isActive ? 1 : 0
        transform: Translate {
          x: screenItem.isActive ? 0 : (screenItem.barPosition === "left" ? -8 : (screenItem.barPosition === "right" ? 8 : 0))
          y: screenItem.isActive ? 0 : (screenItem.barPosition === "top" ? -8 : (screenItem.barPosition === "bottom" ? 8 : 0))
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Style.motionEnter
            easing.type: Easing.OutCubic
          }
        }

        Behavior on x {
          NumberAnimation {
            duration: Style.motionEnter
            easing.type: Easing.OutCubic
          }
        }

        Behavior on y {
          NumberAnimation {
            duration: Style.motionEnter
            easing.type: Easing.OutCubic
          }
        }

        onRequestClose: LauncherState.close(screenItem.modelData)
        onRequestCloseImmediately: LauncherState.close(screenItem.modelData)
      }
    }
  }
}
