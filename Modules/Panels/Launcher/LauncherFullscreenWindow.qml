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

    // Side paddings: calculateBesidePadding() — 180 px, 130 px on <= 1366 wide
    // screens (gxde-launcher calculate_util.cpp:47-54)
    readonly property int sidePadding: screenWidth > Style.launcherSidePaddingBreakpoint ? Style.launcherSidePaddingWide : Style.launcherSidePaddingNarrow

    // Grid geometry (gxde-launcher calculate_util.cpp:104-145). The cell is a
    // square and does not stretch to the container height; the row height is
    // the cell size, so extra vertical space just leaves the grid scrollable.
    readonly property real screenWidth: modelData?.width ?? 0
    readonly property real screenHeight: modelData?.height ?? 0
    readonly property int cellBudget: screenWidth <= Style.launcherCellBudgetBreakpoint ? Style.launcherCellBudgetNarrow : Style.launcherCellBudgetWide
    readonly property int cellSpacing: screenWidth <= Style.launcherCellBudgetBreakpoint ? Style.launcherCellSpacingNarrow : Style.launcherCellSpacingWide
    readonly property real gridWidth: Math.max(1, screenWidth - (sidePadding * 2))
    readonly property int columns: Math.max(1, Math.floor(gridWidth / cellBudget))
    // calc_item_width + 0.5 rounding, then the spacing that makes it fit exactly
    readonly property real cellSize: Math.floor((gridWidth - cellSpacing * columns * 2) / columns + 0.5)
    readonly property real cellWidth: cellSize + cellSpacing
    readonly property real cellHeight: cellSize + cellSpacing
    readonly property real iconSize: Math.round(cellSize * Settings.data.appLauncher.iconRatio)

    // Nav column: 180 px when the screen is wide enough, 130 px otherwise
    readonly property int navWidth: sidePadding

    // The launcher covers the whole output, taskbar area included
    // (fullscreenframe.cpp:1321-1345 only reserves the 60 px bottom band, the
    // dock keeps rendering above the launcher). Content insets:
    //   top    30 px, plus the taskbar thickness when the taskbar is on top
    //   bottom 60 px (VIEWLIST_BOTTOM_MARGIN) plus the thickness when it is at the bottom
    //   left   the taskbar thickness when the taskbar is on the left
    //   right  the taskbar thickness when the taskbar is on the right
    readonly property real taskbarThickness: hasTaskbar ? (efficient ? Style.barHeight : Style.dockItemThickness) : 0
    readonly property real bottomGap: barPosition === "bottom" ? Style.launcherGridBottomMargin + taskbarThickness : 0
    readonly property real topInset: barPosition === "top" ? Style.launcherTopBand + taskbarThickness : Style.launcherTopBand
    readonly property real leftGap: barPosition === "left" ? taskbarThickness : 0
    readonly property real rightGap: barPosition === "right" ? taskbarThickness : 0

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
      // Bottom, not Overlay: the launcher paints the blurred wallpaper itself
      // (it is opaque), and the taskbar lives on the Top layer so it keeps
      // drawing above the launcher and stays clickable (DESIGN §3.4.1,
      // fullscreenframe.cpp updateDockPosition).
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: screenItem.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      // Never reserve space: the launcher must not push the taskbar around
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      color: Qt.rgba(0, 0, 0, 0.55)

      // The layer surface covers the whole output, taskbar area included; the
      // taskbar renders above it (Overlay layer) and stays visible
      // (gxde-launcher fullscreenframe.cpp updateDockPosition).
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      margins {
        top: 0
        bottom: 0
        left: 0
        right: 0
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
        topInset: screenItem.topInset
        bottomGap: screenItem.bottomGap
        sidePadding: screenItem.sidePadding
        navWidth: screenItem.navWidth
        columns: screenItem.columns
        cellWidth: screenItem.cellWidth
        cellHeight: screenItem.cellHeight
        cellSpacing: screenItem.cellSpacing
        iconSize: screenItem.iconSize
        barPosition: screenItem.barPosition
        leftInset: screenItem.leftGap
        rightInset: screenItem.rightGap

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
