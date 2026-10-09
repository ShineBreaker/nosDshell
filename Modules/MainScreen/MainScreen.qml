import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "Backgrounds" as Backgrounds

import qs.Commons

// All panels
import qs.Modules.Bar
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Audio
import qs.Modules.Panels.Battery
import qs.Modules.Panels.Bluetooth
import qs.Modules.Panels.Brightness
import qs.Modules.Panels.Clock
import qs.Modules.Panels.ControlCenter
import qs.Modules.Panels.Launcher
import qs.Modules.Panels.Media
import qs.Modules.Panels.Network
import qs.Modules.Panels.Plugins
import qs.Modules.Panels.SessionMenu
import qs.Modules.Panels.Settings
import qs.Modules.Panels.SetupWizard
import qs.Modules.Panels.SystemStats
import qs.Modules.Panels.Tray
import qs.Modules.Panels.Wallpaper
import qs.Services.Compositor
import qs.Services.Debug
import qs.Services.Power
import qs.Services.UI

/**
* MainScreen - Single PanelWindow per screen that manages all panels and the bar
*/
PanelWindow {
  id: root

  // Scene forensics root: `qs ipc call debug tree main-<screen>` / hit tests.
  property string _dbgName: ""
  Component.onDestruction: {
    if (root._dbgName !== "")
      DebugService.unregisterRoot(root._dbgName);
  }
  onScreenChanged: {
    if (root._dbgName !== "")
      DebugService.unregisterRoot(root._dbgName);
    if (screen && screen.name) {
      root._dbgName = "main-" + screen.name;
      DebugService.registerRoot(root._dbgName, root);
    }
  }

  Component.onCompleted: {
    if (screen && screen.name) {
      root._dbgName = "main-" + screen.name;
      DebugService.registerRoot(root._dbgName, root);
    }
    Logger.d("MainScreen", "Initialized for screen:", screen?.name, "- Dimensions:", screen?.width, "x", screen?.height, "- Position:", screen?.x, ",", screen?.y);
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "nosdshell-background-" + (screen?.name || "unknown")
  WlrLayershell.exclusionMode: ExclusionMode.Ignore // Don't reserve space - BarExclusionZone handles that
  WlrLayershell.keyboardFocus: {
    // No panel open anywhere: no keyboard focus needed
    if (!root.isAnyPanelOpen) {
      return WlrKeyboardFocus.None;
    }
    // Panel open on THIS screen: use panel's preferred focus mode
    if (root.isPanelOpen) {
      // Hyprland's Exclusive captures ALL input globally (including pointer),
      // preventing click-to-close from working on other monitors.
      // Workaround: briefly use Exclusive when panel opens (for text input focus),
      // then switch to OnDemand (for click-to-close on other screens).
      if (CompositorService.isHyprland) {
        return PanelService.isInitializingKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand;
      }
      return PanelService.openedPanel.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand;
    }
    // Panel open on ANOTHER screen: OnDemand allows receiving pointer events for click-to-close
    return WlrKeyboardFocus.OnDemand;
  }

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // Desktop dimming when panels are open
  property real dimmerOpacity: Settings.data.general.dimmerOpacity ?? 0.8
  property bool isPanelOpen: (PanelService.openedPanel !== null) && (PanelService.openedPanel.screen?.name === screen?.name)
  property bool isPanelClosing: (PanelService.openedPanel !== null) && PanelService.openedPanel.isClosing
  property bool isAnyPanelOpen: PanelService.openedPanel !== null

  color: {
    if (dimmerOpacity > 0 && isPanelOpen && !isPanelClosing) {
      return Qt.alpha(Color.mShadow, dimmerOpacity);
    }
    return "transparent";
  }

  Behavior on color {
    enabled: !PanelService.closedImmediately
    ColorAnimation {
      duration: isPanelClosing ? Style.animationFaster : Style.motionEnter
      easing.type: isPanelClosing ? Easing.InCubic : Easing.OutCubic
    }
  }

  // Reset closedImmediately flag after color change is applied
  onColorChanged: {
    if (PanelService.closedImmediately) {
      PanelService.closedImmediately = false;
    }
  }

  // Check if bar should be visible on this screen
  readonly property bool barShouldShow: {
    // Check global bar visibility (includes overview state and dock mode)
    if (!BarService.effectivelyVisible)
      return false;

    return BarService.hasBarOnScreen(screen?.name || "");
  }

  // Make everything click-through except bar
  mask: Region {
    id: clickableMask

    // Cover entire window (everything is masked/click-through)
    x: 0
    y: 0
    width: root.width
    height: root.height
    intersection: Intersection.Xor

    // Only include regions that are actually needed
    // panelRegions is handled by PanelService, bar is local to this screen
    regions: [barMaskRegion, backgroundMaskRegion]

    // Bar region - subtract bar area from mask (only if bar should be shown on this screen)
    Region {
      id: barMaskRegion

      readonly property bool isFramed: Settings.getEffectiveBarType() === "framed"
      readonly property real barThickness: Style.barHeight
      readonly property real frameThickness: Settings.data.bar.frameThickness ?? 12
      readonly property string barPos: Settings.getBarPositionForScreen(root.screen?.name) || "top"

      // Bar / Frame Mask
      Region {
        // Mode: Simple or Floating
        x: barPlaceholder.x
        y: barPlaceholder.y
        width: (!barMaskRegion.isFramed && root.barShouldShow) ? barPlaceholder.width : 0
        height: (!barMaskRegion.isFramed && root.barShouldShow) ? barPlaceholder.height : 0
        intersection: Intersection.Subtract
      }

      // Mode: Framed - 4 sides
      Region {
        // Top side
        Region {
          x: 0
          y: 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? root.width : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "top" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          intersection: Intersection.Subtract
        }

        // Bottom side
        Region {
          x: 0
          y: (barMaskRegion.isFramed && root.barShouldShow) ? (root.height - (barMaskRegion.barPos === "bottom" ? barMaskRegion.barThickness : barMaskRegion.frameThickness)) : 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? root.width : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "bottom" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          intersection: Intersection.Subtract
        }

        // Left side
        Region {
          x: 0
          y: 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "left" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? root.height : 0
          intersection: Intersection.Subtract
        }

        // Right side
        Region {
          x: (barMaskRegion.isFramed && root.barShouldShow) ? (root.width - (barMaskRegion.barPos === "right" ? barMaskRegion.barThickness : barMaskRegion.frameThickness)) : 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "right" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? root.height : 0
          intersection: Intersection.Subtract
        }
      }
    }

    // Background region for click-to-close - reactive sizing
    // Uses isAnyPanelOpen so clicking on any screen's background closes the panel.
    // Launcher windows are standalone layer surfaces on Top, so while one is
    // open the wallpaper must also accept input for the dismiss MouseArea below.
    Region {
      id: backgroundMaskRegion
      x: 0
      y: 0
      width: (root.isAnyPanelOpen || LauncherState.anyOpen) ? root.width : 0
      height: (root.isAnyPanelOpen || LauncherState.anyOpen) ? root.height : 0
      intersection: Intersection.Subtract
    }
  }

  // Blur behind the bar and open panels — attached to PanelWindow (required by BackgroundEffect API)
  // DESIGN §1.2: only request compositor blur when it is actually available.
  // Detach while the bar is fully hidden and no panel is open (e.g. an active
  // fullscreen window): like the dock, a stale region would blur a band where
  // the bar used to be, and re-attaching re-registers the effect on return.
  BackgroundEffect.blurRegion: (Color.blurActive && (!barPlaceholder.effectivelyHidden || root.isAnyPanelOpen)) ? blurRegion : null
  Region {
    id: blurRegion
    // ── Non-framed bar (simple/floating): single rectangle with bar corner states ──
    Region {
      x: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.effectivelyHidden) ? barPlaceholder.x : 0
      y: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.effectivelyHidden) ? barPlaceholder.y : 0
      width: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.effectivelyHidden) ? barPlaceholder.width : 0
      height: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.effectivelyHidden) ? barPlaceholder.height : 0
      radius: Style.radiusL
      topLeftRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(barPlaceholder.topLeftCornerState, Style.radiusL)
      topRightRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(barPlaceholder.topRightCornerState, Style.radiusL)
      bottomLeftRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(barPlaceholder.bottomLeftCornerState, Style.radiusL)
      bottomRightRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(barPlaceholder.bottomRightCornerState, Style.radiusL)
    }

    // ── Framed bar: full screen minus rounded hole ──
    Region {
      x: 0
      y: 0
      width: (barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.effectivelyHidden) ? root.width : 0
      height: (barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.effectivelyHidden) ? root.height : 0

      Region {
        intersection: Intersection.Subtract
        x: backgroundBlur.frameHoleX
        y: backgroundBlur.frameHoleY
        width: backgroundBlur.frameHoleX2 - backgroundBlur.frameHoleX
        height: backgroundBlur.frameHoleY2 - backgroundBlur.frameHoleY
        radius: backgroundBlur.frameR
      }
    }

    // ── Panel blur regions ──
    // Opening panel
    Region {
      x: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.x) : 0
      y: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.y) : 0
      width: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.width) : 0
      height: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.height) : 0
      radius: Style.radiusL
      topLeftRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.panelBg ? backgroundBlur.panelBg.topLeftCornerState : 0, Style.radiusL)
      topRightRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.panelBg ? backgroundBlur.panelBg.topRightCornerState : 0, Style.radiusL)
      bottomLeftRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.panelBg ? backgroundBlur.panelBg.bottomLeftCornerState : 0, Style.radiusL)
      bottomRightRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.panelBg ? backgroundBlur.panelBg.bottomRightCornerState : 0, Style.radiusL)
    }

    // Closing panel (coexists with opening panel during transition)
    Region {
      x: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.x) : 0
      y: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.y) : 0
      width: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.width) : 0
      height: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.height) : 0
      radius: Style.radiusL
      topLeftRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.topLeftCornerState : 0, Style.radiusL)
      topRightRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.topRightCornerState : 0, Style.radiusL)
      bottomLeftRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.bottomLeftCornerState : 0, Style.radiusL)
      bottomRightRadius: Backgrounds.ShapeCornerHelper.getRegionRadius(backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.bottomRightCornerState : 0, Style.radiusL)
    }
  }

  // --------------------------------------
  // Container for all UI elements
  Item {
    id: container
    width: root.width
    height: root.height

    // Unified backgrounds container / unified shadow system
    // Renders all bar and panel backgrounds as ShapePaths within a single Shape
    // This allows the shadow effect to apply to all backgrounds in one render pass
    Backgrounds.AllBackgrounds {
      id: unifiedBackgrounds
      anchors.fill: parent
      bar: barPlaceholder.barItem || null
      windowRoot: root
      z: 0 // Behind all content
    }

    // Background MouseArea for closing panels when clicking outside
    // Uses isAnyPanelOpen so clicking on any screen's background closes the panel
    MouseArea {
      anchors.fill: parent
      enabled: root.isAnyPanelOpen || LauncherState.anyOpen
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: mouse => {
                   if (PanelService.openedPanel) {
                     PanelService.openedPanel.close();
                   }
                   // The launcher windows are standalone layer surfaces, not
                   // openedPanel — a desktop click must retract them too.
                   if (LauncherState.anyOpen) {
                     LauncherState.close(null);
                   }
                 }
      z: 0 // Behind panels and bar
    }

    // ---------------------------------------
    // All panels always exist
    // ---------------------------------------
    AudioPanel {
      id: audioPanel
      objectName: "audioPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    MediaPlayerPanel {
      id: mediaPlayerPanel
      objectName: "mediaPlayerPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    BatteryPanel {
      id: batteryPanel
      objectName: "batteryPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    BluetoothPanel {
      id: bluetoothPanel
      objectName: "bluetoothPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    BrightnessPanel {
      id: brightnessPanel
      objectName: "brightnessPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ControlCenterPanel {
      id: controlCenterPanel
      objectName: "controlCenterPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ClockPanel {
      id: clockPanel
      objectName: "clockPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    Launcher {
      id: launcherPanel
      objectName: "launcherPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SessionMenu {
      id: sessionMenuPanel
      objectName: "sessionMenuPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SettingsPanel {
      id: settingsPanel
      objectName: "settingsPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SetupWizard {
      id: setupWizardPanel
      objectName: "setupWizardPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    TrayDrawerPanel {
      id: trayDrawerPanel
      objectName: "trayDrawerPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    WallpaperPanel {
      id: wallpaperPanel
      objectName: "wallpaperPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    NetworkPanel {
      id: networkPanel
      objectName: "networkPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SystemStatsPanel {
      id: systemStatsPanel
      objectName: "systemStatsPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    // ----------------------------------------------
    // Plugin panel slots
    // ----------------------------------------------
    PluginPanelSlot {
      id: pluginPanel1
      objectName: "pluginPanel1-" + (root.screen?.name || "unknown")
      screen: root.screen
      slotNumber: 1
    }

    PluginPanelSlot {
      id: pluginPanel2
      objectName: "pluginPanel2-" + (root.screen?.name || "unknown")
      screen: root.screen
      slotNumber: 2
    }

    // ----------------------------------------------
    // Bar background placeholder - just for background positioning (actual bar content is in BarContentWindow)
    Item {
      id: barPlaceholder

      // Expose self as barItem for AllBackgrounds compatibility
      readonly property var barItem: barPlaceholder

      // Screen reference
      property ShellScreen screen: root.screen

      // Bar background positioning properties (per-screen)
      readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
      readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
      readonly property bool isFramed: Settings.getEffectiveBarType() === "framed"
      readonly property real frameThickness: Settings.data.bar.frameThickness ?? 12
      readonly property bool barFloating: Settings.getEffectiveBarType() === "floating"
      readonly property real barMarginH: barFloating ? Math.floor(Settings.data.bar.marginHorizontal) : 0
      readonly property real barMarginV: barFloating ? Math.floor(Settings.data.bar.marginVertical) : 0
      readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)

      // Auto-hide properties (read by AllBackgrounds for background fade)
      readonly property bool autoHide: Settings.getBarDisplayModeForScreen(screen?.name) === "auto_hide"
      property bool isHidden: autoHide

      // A fullscreen window on this output covers the bar regardless of the
      // auto-hide mode — mirrors BarContentWindow.effectivelyHidden.
      readonly property bool fullscreenCovered: screen ? CompositorService.outputHasFullscreen(screen.name) : false
      readonly property bool effectivelyHidden: isHidden || fullscreenCovered

      Connections {
        target: BarService
        function onBarAutoHideStateChanged(screenName, hidden) {
          if (screenName === barPlaceholder.screen?.name) {
            barPlaceholder.isHidden = hidden;
          }
        }
      }

      // Expose bar dimensions directly on this Item for BarBackground
      // Use screen dimensions directly.
      // Efficient mode: the background slides off the screen edge when hidden
      // (mirrors BarContentWindow's content slide)
      property real hiddenSlideX: (effectivelyHidden && Settings.data.dock.mode === "efficient") ? (barPosition === "left" ? -barHeight : (barPosition === "right" ? barHeight : 0)) : 0
      property real hiddenSlideY: (effectivelyHidden && Settings.data.dock.mode === "efficient") ? (barPosition === "top" ? -barHeight : (barPosition === "bottom" ? barHeight : 0)) : 0

      Behavior on hiddenSlideX {
        NumberAnimation {
          duration: Style.motionPanel
          easing.type: Easing.InOutCubic
        }
      }
      Behavior on hiddenSlideY {
        NumberAnimation {
          duration: Style.motionPanel
          easing.type: Easing.InOutCubic
        }
      }

      // Geometry derives from the window's own size — the bound screen
      // object may carry stale dimensions (PanelService.liveScreen) and the
      // surface always fills its output anyway.
      x: {
        var bx;
        if (barPosition === "right")
          bx = root.width - barHeight - barMarginH;
        else if (isFramed && !barIsVertical)
          bx = frameThickness;
        else
          bx = barMarginH;
        return bx + hiddenSlideX;
      }
      y: {
        var by;
        if (barPosition === "bottom")
          by = root.height - barHeight - barMarginV;
        else if (isFramed && barIsVertical)
          by = frameThickness;
        else
          by = barMarginV;
        return by + hiddenSlideY;
      }
      width: {
        if (barIsVertical) {
          return barHeight;
        }
        if (isFramed)
          return root.width - frameThickness * 2;
        return root.width - barMarginH * 2;
      }
      height: {
        if (!barIsVertical) {
          return barHeight;
        }
        if (isFramed)
          return root.height - frameThickness * 2;
        return root.height - barMarginV * 2;
      }

      // Corner states (same as Bar.qml)
      readonly property int topLeftCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "top")
          return -1;
        if (barPosition === "left")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "right")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }

      readonly property int topRightCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "top")
          return -1;
        if (barPosition === "right")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "left")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }

      readonly property int bottomLeftCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "bottom")
          return -1;
        if (barPosition === "left")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "right")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }

      readonly property int bottomRightCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "bottom")
          return -1;
        if (barPosition === "right")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "left")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }
    }

    // Screen Corners
    ScreenCorners {}

    // Blur behind the bar and open panels
    // Helper object holding computed properties for blur regions
    QtObject {
      id: backgroundBlur

      // Panel background geometry (from the currently open panel on this screen)
      readonly property var panelBg: {
        var op = PanelService.openedPanel;
        if (!op || op.screen !== root.screen || op.blurEnabled === false)
          return null;
        var region = op.panelRegion;
        return (region && region.visible) ? region.panelItem : null;
      }

      // Panel background geometry for the closing panel (may coexist with panelBg)
      readonly property var closingPanelBg: {
        var cp = PanelService.closingPanel;
        if (!cp || cp.screen !== root.screen || cp.blurEnabled === false)
          return null;
        var region = cp.panelRegion;
        return (region && region.visible) ? region.panelItem : null;
      }

      // Framed bar: inner hole boundary (where the hole begins on each axis)
      // These are the x/y coordinates of the 4 inner hole corners
      readonly property real frameHoleX: barPlaceholder.barPosition === "left" ? barPlaceholder.barHeight : barPlaceholder.frameThickness
      readonly property real frameHoleY: barPlaceholder.barPosition === "top" ? barPlaceholder.barHeight : barPlaceholder.frameThickness
      readonly property real frameHoleX2: root.width - (barPlaceholder.barPosition === "right" ? barPlaceholder.barHeight : barPlaceholder.frameThickness)
      readonly property real frameHoleY2: root.height - (barPlaceholder.barPosition === "bottom" ? barPlaceholder.barHeight : barPlaceholder.frameThickness)
      readonly property real frameR: Settings.data.bar.frameRadius ?? 20
    }

    // Native idle inhibitor — one per active MainScreen window.
    // Multiple inhibitors bound to the same enabled state are harmless;
    // having one per screen is more robust than picking a "primary" screen.
    IdleInhibitor {
      window: root
      enabled: IdleInhibitorService.isInhibited

      Component.onCompleted: {
        IdleInhibitorService.nativeInhibitorAvailable = true;
        Logger.d("IdleInhibitor", "Native IdleInhibitor active on screen:", root.screen?.name);
      }
    }
  }

  // Centralized Keyboard Shortcuts

  // These shortcuts delegate to the opened panel's handler functions
  // Panels can implement: onEscapePressed, onTabPressed, onBackTabPressed,
  // onUpPressed, onDownPressed, onReturnPressed, etc...
  Instantiator {
    model: Settings.data.general.keybinds.keyEscape || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (PanelService.openedPanel.onEscapePressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: PanelService.openedPanel.onEscapePressed()
    }
  }

  Shortcut {
    sequence: "Tab"
    enabled: root.isPanelOpen && (PanelService.openedPanel.onTabPressed !== undefined)
    onActivated: PanelService.openedPanel.onTabPressed()
  }

  Shortcut {
    sequence: "Backtab"
    enabled: root.isPanelOpen && (PanelService.openedPanel.onBackTabPressed !== undefined)
    onActivated: PanelService.openedPanel.onBackTabPressed()
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyUp || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (PanelService.openedPanel.onUpPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: PanelService.openedPanel.onUpPressed()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyDown || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (PanelService.openedPanel.onDownPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: PanelService.openedPanel.onDownPressed()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyEnter || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (PanelService.openedPanel.onEnterPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: PanelService.openedPanel.onEnterPressed()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyLeft || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (PanelService.openedPanel.onLeftPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: PanelService.openedPanel.onLeftPressed()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyRight || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (PanelService.openedPanel.onRightPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: PanelService.openedPanel.onRightPressed()
    }
  }

  Shortcut {
    sequence: "Home"
    enabled: root.isPanelOpen && (PanelService.openedPanel.onHomePressed !== undefined)
    onActivated: PanelService.openedPanel.onHomePressed()
  }

  Shortcut {
    sequence: "End"
    enabled: root.isPanelOpen && (PanelService.openedPanel.onEndPressed !== undefined)
    onActivated: PanelService.openedPanel.onEndPressed()
  }

  Shortcut {
    sequence: "PgUp"
    enabled: root.isPanelOpen && (PanelService.openedPanel.onPageUpPressed !== undefined)
    onActivated: PanelService.openedPanel.onPageUpPressed()
  }

  Shortcut {
    sequence: "PgDown"
    enabled: root.isPanelOpen && (PanelService.openedPanel.onPageDownPressed !== undefined)
    onActivated: PanelService.openedPanel.onPageDownPressed()
  }
}
