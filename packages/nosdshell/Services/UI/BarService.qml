pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Singleton {
  id: root

  property bool isVisible: true

  // Central "is there a bar window on this screen" check.
  // Efficient mode: the taskbar is the bar (dock.enabled + dock.monitors).
  // Fashion mode: the optional status bar (bar.enabled + bar.monitors,
  // independent of the dock — DESIGN §3.7).
  function hasBarOnScreen(screenName) {
    if (Settings.data.dock.mode === "fashion") {
      if (!Settings.data.bar.enabled) {
        return false;
      }
      var barMonitors = Settings.data.bar.monitors || [];
      return barMonitors.length === 0 || barMonitors.includes(screenName);
    }
    if (!Settings.data.dock.enabled) {
      return false;
    }
    // Single multi-screen list: dock.monitors serves both modes (DDE "one taskbar").
    var monitors = Settings.data.dock.monitors || [];
    return monitors.length === 0 || monitors.includes(screenName);
  }

  // Any taskbar (the bar in efficient mode, or the floating dock in fashion
  // mode) configured for this screen. Used by panels/screens gating.
  function hasTaskbarOnScreen(screenName) {
    if (!Settings.data.dock.enabled) {
      return false;
    }
    if (Settings.data.dock.mode === "fashion") {
      var dockMonitors = Settings.data.dock.monitors || [];
      return dockMonitors.length === 0 || dockMonitors.includes(screenName);
    }
    return hasBarOnScreen(screenName);
  }

  // Computed visibility that factors in dock mode and compositor overview state
  readonly property bool effectivelyVisible: {
    if (!isVisible) {
      return false;
    }
    if (Settings.data.dock.mode === "fashion") {
      if (!Settings.data.bar.enabled) {
        return false;
      }
    } else if (!Settings.data.dock.enabled) {
      return false;
    }
    if (Settings.data.bar.hideOnOverview && CompositorService.overviewActive) {
      return false;
    }
    return true;
  }

  // ------------------------------------------------------------------
  // Fashion taskbar geometry bridge. The fashion dock is centred on its
  // long axis, so its start edge is (screen edge - published length) / 2.
  // Modules/Dock/DockContent publishes the length of its surface; the mini
  // launcher reads it to line up with the dock's start edge (DESIGN §3.4.2,
  // gxde-launcher windowedframe.cpp adjustPosition).
  // ------------------------------------------------------------------
  property var dockLengths: ({})
  property int dockLengthsRevision: 0

  function setDockLength(screenName, length) {
    if (!screenName || !isFinite(length) || length <= 0) {
      return;
    }
    if (dockLengths[screenName] === length) {
      return;
    }
    dockLengths[screenName] = length;
    dockLengthsRevision++;
  }

  function getDockLength(screenName) {
    if (!screenName) {
      return 0;
    }
    return dockLengths[screenName] || 0;
  }

  property var readyBars: ({})

  // Revision counter - increment when widget list structure changes (add/remove/reorder)
  // This triggers Bar.qml to re-sync its ListModels
  property int widgetsRevision: 0

  // Registry to store actual widget instances
  // Key format: "screenName|section|widgetId|index"
  property var widgetInstances: ({})

  signal activeWidgetsChanged
  signal barReadyChanged(string screenName)
  signal barAutoHideStateChanged(string screenName, bool hidden)
  signal barHoverStateChanged(string screenName, bool hovered)

  // Track if a popup menu is open from the bar (prevents auto-hide)
  property bool popupOpen: false

  // Auto-hide state per screen: { screenName: { hovered: bool, hidden: bool } }
  property var screenAutoHideState: ({})

  // Get or create auto-hide state for a screen
  function getOrCreateAutoHideState(screenName) {
    if (!screenAutoHideState[screenName]) {
      screenAutoHideState[screenName] = {
        "hovered": false,
        "hidden": Settings.getBarDisplayModeForScreen(screenName) === "auto_hide"
      };
    }
    return screenAutoHideState[screenName];
  }

  // Set hover state for a screen
  function setScreenHovered(screenName, hovered) {
    var state = getOrCreateAutoHideState(screenName);
    if (state.hovered !== hovered) {
      state.hovered = hovered;
      screenAutoHideState = Object.assign({}, screenAutoHideState);
      barHoverStateChanged(screenName, hovered);
    }
  }

  // Set hidden state for a screen
  function setScreenHidden(screenName, hidden) {
    var state = getOrCreateAutoHideState(screenName);
    if (state.hidden !== hidden) {
      state.hidden = hidden;
      screenAutoHideState = Object.assign({}, screenAutoHideState);
      barAutoHideStateChanged(screenName, hidden);
    }
  }

  // Check if bar is hidden on a screen
  function isBarHidden(screenName) {
    var state = screenAutoHideState[screenName];
    return state ? state.hidden : false;
  }

  // Check if bar is hovered on a screen
  function isBarHovered(screenName) {
    var state = screenAutoHideState[screenName];
    return state ? state.hovered : false;
  }

  // Toggle bar visibility. In auto-hide mode, toggles the per-screen hidden
  // state without touching isVisible (so hover-to-show still works).
  // For non-auto-hide screens, toggles the global isVisible flag.
  function toggleVisibility() {
    // Check if any auto-hide screen is currently visible
    var anyAutoHideVisible = false;
    var hasAutoHideScreens = false;
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        hasAutoHideScreens = true;
        if (!screenAutoHideState[screenName].hidden) {
          anyAutoHideVisible = true;
          break;
        }
      }
    }

    // Toggle auto-hide screens (per-screen hidden state only)
    if (hasAutoHideScreens) {
      for (var screenName in screenAutoHideState) {
        if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
          setScreenHidden(screenName, anyAutoHideVisible);
        }
      }
    }

    // Only toggle global visibility when no auto-hide screens exist,
    // otherwise it would permanently disable hover-to-show
    if (!hasAutoHideScreens) {
      isVisible = !isVisible;
    }
  }

  // Show bar. In auto-hide mode, un-hides on screens with auto-hide enabled.
  // The bar stays visible until the user hovers and moves away.
  function show() {
    // Show auto-hide screens
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        setScreenHidden(screenName, false);
      }
    }
    // Set global visibility (affects non-auto-hide screens)
    isVisible = true;
  }

  // Hide bar. In auto-hide mode, sets per-screen hidden state without touching
  // isVisible so hover-to-show still works. For non-auto-hide screens, sets
  // global visibility to false.
  function hide() {
    var hasAutoHideScreens = false;
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        setScreenHidden(screenName, true);
        hasAutoHideScreens = true;
      }
    }
    // Only set global visibility off when no auto-hide screens exist,
    // otherwise it would permanently disable hover-to-show
    if (!hasAutoHideScreens) {
      isVisible = false;
    }
  }

  // Temporarily show the bar, then auto-hide after the configured delay.
  // Uses the same pattern as workspace switch: show, then emit unhover
  // to start the hide timer.
  function peek() {
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        setScreenHidden(screenName, false);
        if (!isBarHovered(screenName)) {
          barHoverStateChanged(screenName, false);
        }
      }
    }
  }

  Component.onCompleted: {
    Logger.i("BarService", "Service started");
  }

  // Bump widgetsRevision when settings are reloaded from an external file change
  // so Bar.qml re-syncs its widget ListModels with the updated widget configuration
  Connections {
    target: Settings
    function onSettingsReloaded() {
      Logger.d("BarService", "Settings reloaded externally, bumping widgetsRevision");
      root.widgetsRevision++;
    }
  }

  // update bar's hidden state when mode changes
  // The live key is dock.hideMode (DDE hide-mode); the legacy
  // bar.displayMode write is dead. getBarDisplayModeForScreen maps it.
  Connections {
    target: Settings.data.dock
    function onHideModeChanged() {
      Logger.d("BarService", "Hide mode changed to:", Settings.data.dock.hideMode);

      // Only affect screens without displayMode overrides
      for (let screenName in screenAutoHideState) {
        if (!Settings.hasScreenOverride(screenName, "displayMode")) {
          var displayMode = Settings.getBarDisplayModeForScreen(screenName);
          if (displayMode === "auto_hide") {
            setScreenHidden(screenName, true);
          } else {
            if (screenAutoHideState[screenName].hidden) {
              setScreenHidden(screenName, false);
            }
          }
        }
      }
    }
  }

  // Screen overrides live under bar.* (compat layout), not dock.*
  Connections {
    target: Settings.data.bar
    function onScreenOverridesChanged() {
      Logger.d("BarService", "Screen overrides changed, re-evaluating auto-hide states");

      for (let screenName in screenAutoHideState) {
        var displayMode = Settings.getBarDisplayModeForScreen(screenName);
        if (displayMode === "auto_hide") {
          if (!screenAutoHideState[screenName].hidden) {
            setScreenHidden(screenName, true);
          }
        } else {
          if (screenAutoHideState[screenName].hidden) {
            setScreenHidden(screenName, false);
          }
        }
      }
    }
  }

  // Track last workspace ID to detect actual workspace changes
  property var lastWorkspaceId: null

  // Debounce rapid workspace switches to reduce load/unload races (SIGSEGV in QV4)
  property string _pendingWorkspaceScreen: ""

  Timer {
    id: workspaceDebounceTimer
    interval: 80
    repeat: false
    onTriggered: {
      var screen = root._pendingWorkspaceScreen;
      root._pendingWorkspaceScreen = "";
      if (screen) {
        setScreenHidden(screen, false);
        if (!root.isBarHovered(screen)) {
          barHoverStateChanged(screen, false);
        }
      }
    }
  }

  // Workspace switch handler - directly show bar on the focused workspace screen
  Connections {
    target: CompositorService
    function onWorkspaceChanged() {
      if (!Settings.data.bar.showOnWorkspaceSwitch)
        return;

      var ws = CompositorService.getCurrentWorkspace();
      if (!ws || !ws.output) {
        return;
      }
      // Live key is dock.hideMode (mapped via screen overrides); the legacy
      // bar.displayMode write is dead, so gating on it never fired.
      if (Settings.getBarDisplayModeForScreen(ws.output) !== "auto_hide")
        return;

      // Only trigger if workspace actually changed
      var currentWsId = ws.id;
      if (currentWsId === root.lastWorkspaceId) {
        return;
      }
      root.lastWorkspaceId = currentWsId;

      var screenName = ws.output || "";
      Logger.d("BarService", "Workspace switched to:", currentWsId, "on screen:", screenName);

      // Debounce: rapid switches (e.g. external monitor ↔ laptop) cause overlapping
      // bar load/unload; 80ms delay coalesces them and reduces QV4 incubation races
      root._pendingWorkspaceScreen = screenName;
      workspaceDebounceTimer.restart();
    }
  }

  // Function for the Bar to call when it's ready
  function registerBar(screenName) {
    if (!readyBars[screenName]) {
      readyBars[screenName] = true;
      Logger.d("BarService", "Bar is ready on screen:", screenName);
      barReadyChanged(screenName);
    }
  }

  // Function for the Dock to check if the bar is ready
  function isBarReady(screenName) {
    return readyBars[screenName] || false;
  }

  // Register a widget instance
  function registerWidget(screenName, section, widgetId, index, instance) {
    const key = [screenName, section, widgetId, index].join("|");
    widgetInstances[key] = {
      "key": key,
      "screenName": screenName,
      "section": section,
      "widgetId": widgetId,
      "index": index,
      "instance": instance
    };

    Logger.d("BarService", "Registered widget:", key);
    root.activeWidgetsChanged();
  }

  // Unregister a widget instance
  function unregisterWidget(screenName, section, widgetId, index) {
    const key = [screenName, section, widgetId, index].join("|");
    delete widgetInstances[key];
    Logger.d("BarService", "Unregistered widget:", key);
    root.activeWidgetsChanged();
  }

  // Lookup a specific widget instance (returns the actual QML instance)
  function lookupWidget(widgetId, screenName = null, section = null, index = null) {
    // If looking for a specific instance
    if (screenName && section !== null) {
      for (var key in widgetInstances) {
        var widget = widgetInstances[key];
        if (!widget)
          continue;
        if (widget.widgetId === widgetId && widget.screenName === screenName && widget.section === section) {
          if (index === null) {
            return widget.instance;
          } else if (widget.index == index) {
            return widget.instance;
          }
        }
      }
    }

    // Return first match if no specific screen/section specified
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.widgetId === widgetId) {
        if (!screenName || widget.screenName === screenName) {
          if (section === null || widget.section === section) {
            return widget.instance;
          }
        }
      }
    }

    return undefined;
  }

  // Get all instances of a widget type
  function getAllWidgetInstances(widgetId = null, screenName = null, section = null) {
    var instances = [];

    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;

      var matches = true;
      if (widgetId && widget.widgetId !== widgetId)
        matches = false;
      if (screenName && widget.screenName !== screenName)
        matches = false;
      if (section !== null && widget.section !== section)
        matches = false;

      if (matches) {
        instances.push(widget.instance);
      }
    }

    return instances;
  }

  // Get widget with full metadata
  function getWidgetWithMetadata(widgetId, screenName = null, section = null) {
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.widgetId === widgetId) {
        if (!screenName || widget.screenName === screenName) {
          if (section === null || widget.section === section) {
            return widget;
          }
        }
      }
    }
    return undefined;
  }

  // Get all widgets in a specific section
  function getWidgetsBySection(section, screenName = null) {
    var widgetEntries = [];

    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.section === section) {
        if (!screenName || widget.screenName === screenName) {
          widgetEntries.push(widget);
        }
      }
    }

    // Sort by index to maintain order
    widgetEntries.sort(function (a, b) {
      return (a.index || 0) - (b.index || 0);
    });

    // Return just the instances
    return widgetEntries.map(function (w) {
      return w.instance;
    });
  }

  // Get all registered widgets (for debugging)
  function getAllRegisteredWidgets() {
    var result = [];
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      result.push({
                    "key": key,
                    "widgetId": widget.widgetId,
                    "section": widget.section,
                    "screenName": widget.screenName,
                    "index": widget.index
                  });
    }
    return result;
  }

  // Check if a widget type exists in a section
  function hasWidget(widgetId, section = null, screenName = null) {
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.widgetId === widgetId) {
        if (section === null || widget.section === section) {
          if (!screenName || widget.screenName === screenName) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Unregister all widget instances for a plugin (used during hot reload)
  // Note: We don't destroy instances here - the Loader manages that when the component is unregistered
  function destroyPluginWidgetInstances(pluginId) {
    var widgetId = "plugin:" + pluginId;
    var keysToRemove = [];

    // Find all instances of this plugin's widget
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (widget && widget.widgetId === widgetId) {
        keysToRemove.push(key);
        Logger.d("BarService", "Unregistering plugin widget instance:", key);
      }
    }

    // Remove from registry
    for (var i = 0; i < keysToRemove.length; i++) {
      delete widgetInstances[keysToRemove[i]];
    }

    if (keysToRemove.length > 0) {
      Logger.i("BarService", "Unregistered", keysToRemove.length, "instance(s) of plugin widget:", widgetId);
      root.activeWidgetsChanged();
    }
  }

  // Get pill direction for a widget instance
  function getPillDirection(widgetInstance) {
    try {
      if (widgetInstance.section === "left") {
        return false;
      } else if (widgetInstance.section === "right") {
        return true;
      } else {
        // middle section
        if (widgetInstance.sectionWidgetIndex < widgetInstance.sectionWidgetsCount / 2) {
          return true;
        } else {
          return false;
        }
      }
    } catch (e) {
      Logger.e(e);
    }
    return true;
  }

  // dockHosted: the widget lives in the fashion dock, so its tooltip must
  // point away from the taskbar edge rather than the status-bar edge.
  function getTooltipDirection(screenName, dockHosted) {
    const position = dockHosted ? Settings.getTaskbarPositionForScreen(screenName) : Settings.getBarPositionForScreen(screenName);
    switch (position) {
    case "right":
      return "left";
    case "left":
      return "right";
    case "bottom":
      return "top";
    default:
      return "bottom";
    }
  }

  // Thickness of the shell strip occupying `edge` on `screenName`: the bar
  // window (the efficient taskbar, or the fashion status bar — barHeight) or
  // the floating fashion dock (dockItemThickness). When both share an edge
  // the strip is the union, so the larger thickness wins. Surfaces drawn
  // under these windows (context menus, edge sheets) use this to stay clear.
  function edgeStripThickness(screenName, edge) {
    if (!screenName)
      return 0;
    var t = 0;
    if (hasBarOnScreen(screenName) && Settings.getBarPositionForScreen(screenName) === edge) {
      t = Style.getBarHeightForScreen(screenName);
    }
    if (Settings.data.dock.mode === "fashion" && hasTaskbarOnScreen(screenName) && Settings.getTaskbarPositionForScreen(screenName) === edge) {
      t = Math.max(t, Style.dockItemThickness);
    }
    return t;
  }

  // Thickness of the bar window's strip on `edge` — the efficient taskbar
  // or the fashion status bar. Unlike edgeStripThickness this excludes the
  // floating dock: the dock is a capsule on the Overlay layer that paints
  // above panels, so panels stay edge-flush under it rather than insetting
  // a full-height gap it doesn't fill (DESIGN §3.13).
  function edgeBarThickness(screenName, edge) {
    if (!screenName || !hasBarOnScreen(screenName))
      return 0;
    return Settings.getBarPositionForScreen(screenName) === edge ? Style.getBarHeightForScreen(screenName) : 0;
  }

  // Edge space the bar window actually reserves on `screenName` — mirrors
  // BarExclusionZone's ExclusionMode.Auto: persistent bars only, floating
  // margin included, framed mode reserves its frameThickness strip on the
  // three non-bar edges. Auto-hidden, non-exclusive and IPC-hidden bars
  // reserve nothing; the floating dock never reserves (it overlays
  // instead). gxde's primaryRect (frame.cpp:471) is this same work-area
  // semantics.
  function edgeReservedThickness(screenName, edge) {
    if (!screenName || !isVisible)
      return 0;
    if (!hasBarOnScreen(screenName))
      return 0;
    var dm = Settings.getBarDisplayModeForScreen(screenName);
    if (dm === "auto_hide" || dm === "non_exclusive")
      return 0;
    if (Settings.getBarPositionForScreen(screenName) === edge) {
      var t = Style.getBarHeightForScreen(screenName);
      if (Settings.isBarFloating()) {
        t += Math.ceil((edge === "left" || edge === "right") ? Settings.data.bar.marginHorizontal : Settings.data.bar.marginVertical);
      }
      return t;
    }
    // Framed: the ring band sits on every edge; floating lifts it by the
    // float margin too (DESIGN §3.13).
    if (Settings.getEffectiveBarType() === "framed") {
      var ft = Settings.data.bar.frameThickness;
      if (Settings.isBarFloating()) {
        ft += Math.ceil((edge === "left" || edge === "right") ? Settings.data.bar.marginHorizontal : Settings.data.bar.marginVertical);
      }
      return ft;
    }
    return 0;
  }

  // Space a surface must leave on `edge` of `screenName` so no shell
  // furniture clips it: the strip occupying the edge — the bar window or
  // the floating fashion dock (edgeStripThickness), plus the float margin
  // when a floating bar window is what sits there — or, on the edges the
  // bar is not on, a framed bar's ring band. 0 when the edge is bare.
  // edgeStripThickness measures the windows only; bubbles, menus and edge
  // sheets that must stay visually clear of the margin and the ring use
  // this instead.
  function edgeClearance(screenName, edge) {
    if (!screenName)
      return 0;
    const isV = edge === "top" || edge === "bottom";
    const floatM = Settings.isBarFloating()
        ? Math.ceil(isV ? Settings.data.bar.marginVertical : Settings.data.bar.marginHorizontal)
        : 0;
    const strip = edgeStripThickness(screenName, edge);
    if (!hasBarOnScreen(screenName))
      return strip;
    if (Settings.getBarPositionForScreen(screenName) === edge) {
      // Occupied by the bar window: floating lifts the strip off the edge.
      return Math.max(strip, Style.getBarHeightForScreen(screenName) + floatM);
    }
    if (Settings.getEffectiveBarType() === "framed") {
      // The ring band sits on every edge, the float margin lifts it too.
      return Math.max(strip, Settings.data.bar.frameThickness + floatM);
    }
    return strip;
  }

  // Merge a settings payload onto a stored widget entry, preserving the
  // entry's id — the id is structural (it names which widget the slot is), so
  // a payload must never rename the slot even if it carries a foreign one.
  function _mergedWidgetEntry(existing, settings) {
    var merged = Object.assign({}, existing, settings);
    if (existing && existing.id && merged.id !== existing.id) {
      Logger.w("BarService", "settings payload id '" + merged.id + "' does not match slot id '" + existing.id + "' — keeping entry identity");
      merged.id = existing.id;
    }
    return merged;
  }

  // Helper to close any existing dialogs in a popup menu window
  function closeExistingDialogs(popupMenuWindow) {
    if (!popupMenuWindow || !popupMenuWindow.dialogParent)
      return;

    var dialogParent = popupMenuWindow.dialogParent;
    for (var i = dialogParent.children.length - 1; i >= 0; i--) {
      var child = dialogParent.children[i];
      if (child && typeof child.close === "function") {
        child.close();
      }
    }
    popupMenuWindow.dialogItem = null;
  }

  // Open widget settings dialog for a bar widget
  // Parameters:
  //   screen: The screen to show the dialog on
  //   section: Section id ("left", "center", "right")
  //   index: Widget index in section
  //   widgetId: Widget type id (e.g., "Volume")
  //   widgetData: Current widget settings object
  function openWidgetSettings(screen, section, index, widgetId, widgetData) {
    // Get the popup menu window to use as parent (avoids clipping issues with bar height)
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (!popupMenuWindow) {
      Logger.e("BarService", "No popup menu window found for screen");
      return;
    }

    // Close any existing dialogs first to prevent stacking
    closeExistingDialogs(popupMenuWindow);

    if (PanelService.openedPanel) {
      PanelService.openedPanel.close();
    }

    var component = Qt.createComponent(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml");

    function instantiateAndOpen() {
      // Use dialogParent (Item) instead of window directly for proper Popup anchoring
      var dialog = component.createObject(popupMenuWindow.dialogParent, {
                                            "widgetIndex": index,
                                            "widgetData": widgetData,
                                            "widgetId": widgetId,
                                            "sectionId": section,
                                            "screen": screen
                                          });

      if (dialog) {
        dialog.updateWidgetSettings.connect((sec, idx, settings) => {
                                              var screenName = screen?.name || "";
                                              if (sec === "dock") {
                                                // Fashion dock plugins: the per-instance entry lives in
                                                // dock.plugins (global, not per-screen); bar widget
                                                // sections never carry a "dock" key.
                                                Settings.setDockPluginSettings(idx, settings);
                                              } else if (Settings.hasScreenOverride(screenName, "widgets")) {
                                                var overrideWidgets = Settings.getBarWidgetsForScreen(screenName);
                                                if (overrideWidgets && overrideWidgets[sec] && idx < overrideWidgets[sec].length) {
                                                  overrideWidgets[sec][idx] = _mergedWidgetEntry(overrideWidgets[sec][idx], settings);
                                                  Settings.setScreenOverride(screenName, "widgets", overrideWidgets);
                                                }
                                              } else if (Settings.data.dock.mode === "efficient") {
                                                if (sec === "right") {
                                                  // Right section entries map 1:1 onto dock.plugins
                                                  Settings.setDockPluginSettings(idx, settings);
                                                } else {
                                                  // Left/center zone entries live verbatim in
                                                  // dock.taskbarWidgets — previously these writes
                                                  // fell through to bar.widgets and silently
                                                  // corrupted the status-bar layout.
                                                  var zone = Settings.data.dock.taskbarWidgets[sec];
                                                  if (zone && idx < zone.length) {
                                                    zone[idx] = _mergedWidgetEntry(zone[idx], settings);
                                                    Settings.data.dock.taskbarWidgets[sec] = zone;
                                                    Settings.saveImmediate();
                                                  }
                                                }
                                              } else {
                                                var widgets = Settings.data.bar.widgets[sec];
                                                if (widgets && idx < widgets.length) {
                                                  widgets[idx] = _mergedWidgetEntry(widgets[idx], settings);
                                                  Settings.data.bar.widgets[sec] = widgets;
                                                  Settings.saveImmediate();
                                                }
                                              }
                                            });
        // Keyboard focus + blur region + window close wiring come with the
        // host; the caller side only destroys the object it created.
        popupMenuWindow.hostDialog(dialog);
        dialog.closed.connect(() => {
                                dialog.destroy();
                              });
        dialog.open();
      } else {
        Logger.e("BarService", "Failed to create widget settings dialog");
      }
    }

    if (component.status === Component.Ready) {
      instantiateAndOpen();
    } else if (component.status === Component.Error) {
      Logger.e("BarService", "Error loading widget settings dialog:", component.errorString());
    } else {
      component.statusChanged.connect(function () {
        if (component.status === Component.Ready) {
          instantiateAndOpen();
        } else if (component.status === Component.Error) {
          Logger.e("BarService", "Error loading widget settings dialog:", component.errorString());
        }
      });
    }
  }

  // Open plugin settings dialog
  // Parameters:
  //   screen: The screen to show the dialog on
  //   pluginManifest: The plugin's manifest object (must have entryPoints.settings)
  function openPluginSettings(screen, pluginManifest) {
    if (!pluginManifest || !pluginManifest.entryPoints || !pluginManifest.entryPoints.settings) {
      Logger.e("BarService", "Cannot open plugin settings: no settings entry point");
      return;
    }

    // Get the popup menu window to use as parent
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (!popupMenuWindow) {
      Logger.e("BarService", "No popup menu window found for screen");
      return;
    }

    // Close any existing dialogs first to prevent stacking
    closeExistingDialogs(popupMenuWindow);

    var component = Qt.createComponent(Quickshell.shellDir + "/Widgets/NPluginSettingsPopup.qml");

    function instantiateAndOpen() {
      var dialog = component.createObject(popupMenuWindow.dialogParent, {
                                            "showToastOnSave": true,
                                            "screen": screen
                                          });

      if (dialog) {
        // Keyboard focus + blur region + window close wiring come with the
        // host; the caller side only destroys the object it created.
        popupMenuWindow.hostDialog(dialog);
        dialog.closed.connect(() => {
                                dialog.destroy();
                              });
        dialog.openPluginSettings(pluginManifest);
      } else {
        Logger.e("BarService", "Failed to create plugin settings dialog");
      }
    }

    if (component.status === Component.Ready) {
      instantiateAndOpen();
    } else if (component.status === Component.Error) {
      Logger.e("BarService", "Error loading plugin settings dialog:", component.errorString());
    } else {
      component.statusChanged.connect(function () {
        if (component.status === Component.Ready) {
          instantiateAndOpen();
        } else if (component.status === Component.Error) {
          Logger.e("BarService", "Error loading plugin settings dialog:", component.errorString());
        }
      });
    }
  }
}
