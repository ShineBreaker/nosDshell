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

    // modelData can hold a ShellScreen the compositor later replaced —
    // geometry and screen matching go through the live object by name
    // (PanelService.liveScreen).
    readonly property ShellScreen liveScreen: PanelService.liveScreen(modelData)

    // The layer surface exists for the whole session; LauncherState decides
    // whether it shows and takes keyboard focus.
    readonly property bool isActive: modelData !== null && LauncherState.miniOpen && LauncherState.miniScreen?.name === modelData?.name

    // Close animation: hold the surface mapped while the view slides/fades
    // back toward the taskbar edge, then unmap.
    onIsActiveChanged: {
      if (!isActive)
        closeTimer.restart();
      else
        closeTimer.stop();
    }
    Timer {
      id: closeTimer
      interval: Style.animationFast + 30
    }

    // -----------------------------------------------------------
    // Geometry (gxde-launcher windowedframe.cpp adjustPosition)
    // -----------------------------------------------------------
    // The mini launcher hugs the taskbar/dock edge, not the optional status bar
    readonly property string barPosition: Settings.getTaskbarPositionForScreen(modelData?.name ?? "")
    readonly property bool efficient: Settings.data.dock.mode === "efficient"

    readonly property real windowWidth: Style.launcherMiniLeftPaneWidth + Style.launcherMiniRightPaneWidth
    readonly property real windowHeight: Style.launcherMiniHeight
    // 1 px off the taskbar (windowedframe.cpp adjustPosition)
    readonly property real gap: Style.launcherMiniDockGap

    // Cross-axis thickness of the taskbar strip: the efficient bar's height,
    // or the fashion dock's item box (BarService.edgeClearance — the union
    // also covers a status bar sharing the edge, and the float margin).
    // DDE reads this straight off dockRect.
    readonly property real barThickness: BarService.edgeClearance(modelData?.name ?? "", barPosition)

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
        return (liveScreen?.width ?? 0) - barThickness - gap - windowWidth;
      default:
        return gap;
      }
    }

    readonly property real cornerY: {
      switch (barPosition) {
      case "top":
        return barThickness + gap;
      case "bottom":
        return (liveScreen?.height ?? 0) - barThickness - gap - windowHeight;
      default:
        return gap;
      }
    }

    // Fashion mode: line the window up with the dock's start edge on the long
    // axis and sit flush against the dock on the short one
    // (windowedframe.cpp:773-789 — p.x / p.y come from dockRect).
    readonly property real fashionX: {
      const screenW = liveScreen?.width ?? 0;
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
      const screenH = liveScreen?.height ?? 0;
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

      screen: screenItem.liveScreen
      visible: screenItem.isActive || closeTimer.running
      color: "transparent"

      // §1.2: blur behind the panel body when the compositor offers it. The
      // open/close slide runs on surface's Translate transform, so the region
      // tracks panelBg and the sentinel feeds the animated slide values
      // (NSurfaceRegion).
      BackgroundEffect.blurRegion: miniBlurRegion.region
      NSurfaceRegion {
        id: miniBlurRegion

        trackedItem: panelBg
        radius: Style.radiusItem
        // Detach while hidden: niri keeps the last-seen ext-background-effect
        // region for a composited/unmapped surface, leaving a blurred ghost
        // rect where the window used to be (same class as 72808f3fd on the
        // dock strip). Swap to the empty region as soon as the window is no
        // longer active — the last committed state before unmap must be empty.
        // blurActive rides the same object swap instead of a null assignment.
        activeWhen: Colors.blurActive && screenItem.isActive
        slideX: surface.slideX
        slideY: surface.slideY
      }
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

      // Opening animation: fade + 8 px slide from the taskbar side, applied
      // to the whole panel surface — the opaque background and the content
      // must move together. The slide lives on a real property bound into
      // the Translate: a binding inside transform has nothing to animate it.
      Item {
        id: surface

        anchors.fill: parent

        property real slideX: screenItem.isActive ? 0 : (screenItem.barPosition === "left" ? -8 : (screenItem.barPosition === "right" ? 8 : 0))
        property real slideY: screenItem.isActive ? 0 : (screenItem.barPosition === "top" ? -8 : (screenItem.barPosition === "bottom" ? 8 : 0))
        opacity: screenItem.isActive ? 1 : 0
        transform: Translate {
          x: surface.slideX
          y: surface.slideY
        }

        // Exit runs on the shorter animationFast window — closeTimer unmaps
        // the surface right after it.
        Behavior on opacity {
          NumberAnimation {
            duration: screenItem.isActive ? Style.motionEnter : Style.animationFast
            easing.type: screenItem.isActive ? Easing.OutCubic : Easing.InCubic
          }
        }
        Behavior on slideX {
          NumberAnimation {
            duration: screenItem.isActive ? Style.motionEnter : Style.animationFast
            easing.type: screenItem.isActive ? Easing.OutCubic : Easing.InCubic
          }
        }
        Behavior on slideY {
          NumberAnimation {
            duration: screenItem.isActive ? Style.motionEnter : Style.animationFast
            easing.type: screenItem.isActive ? Easing.OutCubic : Easing.InCubic
          }
        }

        // The panel surface: maskShell, 1 px overlay("hover") border,
        // radius radiusItem.
        // ponytail: per-corner radius (radiusLarge on the taskbar-side corner in
        // efficient mode) would need a Canvas or a mask image; QML Rectangle
        // only supports a uniform radius. Upgrade if the corner becomes
        // visually load-bearing.
        Rectangle {
          id: panelBg
          anchors.fill: parent
          color: Colors.maskShell
          radius: Style.radiusItem
          border.width: Style.borderS
          border.color: Colors.borderShell
        }

        LauncherMiniView {
          id: view

          anchors.fill: parent
          screen: screenItem.liveScreen
          barPosition: screenItem.barPosition

          enabled: screenItem.isActive

          onRequestClose: LauncherState.close(screenItem.liveScreen)
          onRequestCloseImmediately: LauncherState.close(screenItem.liveScreen)
        }
      }
    }
  }
}
