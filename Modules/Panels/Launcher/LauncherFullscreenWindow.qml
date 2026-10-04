import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

// Fullscreen launcher window (DESIGN §3.4.1). One full-screen Overlay-layer
// surface per screen; the taskbar region stays free on its side (the content is
// inset by the bar thickness when the dock sits at top/bottom).
// Mirrors the OSD pattern: a Variants over screens with a Loader + PanelWindow,
// where visibility is driven by LauncherState rather than Loader re-creation
// (a layer surface re-created on every toggle would drop keyboard focus).
Variants {
  id: root

  model: Quickshell.screens

  // The Loader is the delegate itself (mirrors OSD's structure): a wrapping
  // Item stays unsized and never creates its children.
  delegate: Loader {
    id: screenItem

    required property ShellScreen modelData

    // The layer surface exists for the whole session; LauncherState decides
    // whether it shows and takes keyboard focus.
    readonly property bool isActive: modelData !== null && LauncherState.fullscreenOpen && LauncherState.fullscreenScreen === modelData

    readonly property string barPosition: Settings.getBarPositionForScreen(modelData?.name ?? "")
    readonly property bool hasTaskbar: BarService.hasTaskbarOnScreen(modelData?.name ?? "")
    readonly property bool efficient: Settings.data.dock.mode === "efficient"
    // Cross-axis thickness of the taskbar on its edge; the launcher surface
    // leaves this band uncovered (plus 6 px) so the dock stays visible and
    // usable — DDE fullscreen launcher keeps the dock interactive
    // (gxde-launcher fullscreenframe.cpp dockGeometry passthrough).
    readonly property real taskbarThickness: hasTaskbar ? (efficient ? Style.barHeight : Style.dockItemThickness) : 0

    // Side paddings: 200 px (DESIGN §3.4.1)
    readonly property int sidePadding: 200

    // Nav column: 180 px when the screen is wide enough, 130 px otherwise
    readonly property int navWidth: (modelData?.width ?? 0) > 1366 ? 180 : 130

    // Grid geometry (DESIGN §3.4.1 / gxde-launcher calculate_util.cpp)
    readonly property real screenWidth: modelData?.width ?? 0
    readonly property int cellBudget: screenWidth <= 1440 ? 170 : 200
    readonly property int cellSpacing: screenWidth <= 1440 ? 10 : 14
    readonly property real gridWidth: Math.max(200, screenWidth - (sidePadding * 2))
    readonly property int columns: Math.max(1, Math.floor(gridWidth / cellBudget))
    readonly property real cellWidth: Math.floor(gridWidth / columns)
    readonly property real cellHeight: cellWidth + 78
    readonly property real iconSize: Math.round(cellWidth * Settings.data.appLauncher.iconRatio)

    // Band left free on the taskbar's side (thickness + 6 px breathing room)
    readonly property real bottomGap: barPosition === "bottom" ? taskbarThickness + 6 : 0
    readonly property real topInset: barPosition === "top" ? taskbarThickness + 6 : 0
    readonly property real leftGap: barPosition === "left" ? taskbarThickness + 6 : 0
    readonly property real rightGap: barPosition === "right" ? taskbarThickness + 6 : 0

    // The surface is created on first open (like OSD) and then reused, so
    // toggling does not drop keyboard focus.
    property bool _surfaceReady: false

    active: screenItem._surfaceReady
    asynchronous: false

    Connections {
      target: LauncherState
      function onOpened() {
        if (LauncherState.fullscreenScreen === screenItem.modelData)
        screenItem._surfaceReady = true;
      }
    }

    // Opening animation: fade (Style.motionEnter)
    sourceComponent: PanelWindow {
      id: window

      screen: screenItem.modelData
      visible: screenItem.isActive

      // The layer surface fills the output; give the window an implicit size so
      // the content item (and the layouts inside it) is laid out.
      implicitWidth: modelData?.width ?? 0
      implicitHeight: modelData?.height ?? 0

      WlrLayershell.namespace: "nosd-launcher-full-" + (screen?.name || "unknown")
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: screenItem.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      color: Qt.rgba(0, 0, 0, 0.55)

      // Fullscreen layer surface: fill the output minus the taskbar band, so
      // the dock renders above it and stays clickable (DDE behaviour).
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      margins {
        top: screenItem.topInset
        bottom: screenItem.bottomGap
        left: screenItem.leftGap
        right: screenItem.rightGap
      }

      // Pre-blurred wallpaper background, black underneath (DESIGN §1.8)
      LauncherBackground {
        id: background
        anchors.fill: parent
        screen: screenItem.modelData
        opacity: screenItem.isActive ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: Style.motionEnter
            easing.type: Easing.OutCubic
          }
        }
      }

      LauncherFullscreenView {
        id: view

        anchors.fill: parent
        screen: screenItem.modelData
        // The surface itself is already inset by the taskbar band via
        // `margins` — the view must not inset a second time.
        topInset: 0
        bottomGap: 0
        sidePadding: screenItem.sidePadding
        navWidth: screenItem.navWidth
        columns: screenItem.columns
        cellWidth: screenItem.cellWidth
        cellHeight: screenItem.cellHeight
        cellSpacing: screenItem.cellSpacing
        iconSize: screenItem.iconSize
        barPosition: screenItem.barPosition

        enabled: screenItem.isActive
        opacity: screenItem.isActive ? 1 : 0

        Behavior on opacity {
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
