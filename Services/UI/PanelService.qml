pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor

Singleton {
  id: root

  // A ref. to the lockScreen, so it's accessible from anywhere.
  property var lockScreen: null

  // Panels
  property var registeredPanels: ({})
  property var openedPanel: null
  property var closingPanel: null
  property bool closedImmediately: false

  // Brief window after panel opens where Exclusive keyboard is allowed on Hyprland
  // This allows text inputs to receive focus, then switches to OnDemand for click-to-close
  property bool isInitializingKeyboard: false

  // Global state for keybind recording components to block global shortcuts
  property bool isKeybindRecording: false

  signal willOpen
  signal didClose

  // Background slot assignments for dynamic panel background rendering
  // Slot 0: currently opening/open panel, Slot 1: closing panel
  property var backgroundSlotAssignments: [null, null]
  signal slotAssignmentChanged(int slotIndex, var panel)

  function assignToSlot(slotIndex, panel) {
    if (backgroundSlotAssignments[slotIndex] !== panel) {
      var newAssignments = backgroundSlotAssignments.slice();
      newAssignments[slotIndex] = panel;
      backgroundSlotAssignments = newAssignments;
      slotAssignmentChanged(slotIndex, panel);
    }
  }

  // Popup menu windows (one per screen) - used for both tray menus and context menus
  property var popupMenuWindows: ({})
  signal popupMenuWindowRegistered(var screen)

  // Register this panel (called after panel is loaded)
  function registerPanel(panel) {
    registeredPanels[panel.objectName] = panel;
    Logger.d("PanelService", "Registered panel:", panel.objectName);
  }

  // Register popup menu window for a screen
  function registerPopupMenuWindow(screen, window) {
    if (!screen || !window)
      return;
    var key = screen.name;
    popupMenuWindows[key] = window;
    Logger.d("PanelService", "Registered popup menu window for screen:", key);
    popupMenuWindowRegistered(screen);
  }

  // Unregister popup menu window for a screen (called on destruction)
  function unregisterPopupMenuWindow(screen) {
    if (!screen)
      return;
    var key = screen.name;
    delete popupMenuWindows[key];
    Logger.d("PanelService", "Unregistered popup menu window for screen:", key);
  }

  // Get popup menu window for a screen
  function getPopupMenuWindow(screen) {
    if (!screen)
      return null;
    return popupMenuWindows[screen.name] || null;
  }

  // Show a context menu with proper handling for all compositors
  // Optional targetItem: if provided, menu will be horizontally centered on this item instead of anchorItem
  function showContextMenu(contextMenu, anchorItem, screen, targetItem) {
    if (!contextMenu || !anchorItem)
      return;

    // Close any previously opened context menu first
    closeContextMenu(screen);

    var popupMenuWindow = getPopupMenuWindow(screen);
    if (popupMenuWindow) {
      popupMenuWindow.showContextMenu(contextMenu);
      contextMenu.openAtItem(anchorItem, screen, targetItem);
    }
  }

  // Close any open context menu or popup menu window
  function closeContextMenu(screen) {
    var popupMenuWindow = getPopupMenuWindow(screen);
    if (popupMenuWindow && popupMenuWindow.visible) {
      popupMenuWindow.close();
    }
  }

  // Show a tray menu with proper handling for all compositors
  // Returns true if menu was shown successfully
  function showTrayMenu(screen, trayItem, trayMenu, anchorItem, menuX, menuY, widgetSection, widgetIndex) {
    if (!trayItem || !trayMenu || !anchorItem)
      return false;

    // Close any previously opened menu first
    closeContextMenu(screen);

    trayMenu.trayItem = trayItem;
    trayMenu.widgetSection = widgetSection;
    trayMenu.widgetIndex = widgetIndex;

    var popupMenuWindow = getPopupMenuWindow(screen);
    if (popupMenuWindow) {
      popupMenuWindow.open();
      trayMenu.showAt(anchorItem, menuX, menuY);
    } else {
      return false;
    }
    return true;
  }

  // Close tray menu
  function closeTrayMenu(screen) {
    var popupMenuWindow = getPopupMenuWindow(screen);
    if (popupMenuWindow) {
      // This closes both the window and calls hideMenu on the tray menu
      popupMenuWindow.close();
    }
  }

  // Find a fallback screen, prioritizing 0x0 position (primary)
  function findFallbackScreen() {
    let primaryCandidate = null;
    let firstScreen = null;

    for (let i = 0; i < Quickshell.screens.length; i++) {
      const s = Quickshell.screens[i];
      if (s.x === 0 && s.y === 0) {
        primaryCandidate = s;
      }
      if (!firstScreen) {
        firstScreen = s;
      }
    }

    return primaryCandidate || firstScreen || null;
  }

  // Host a reusable settings Popup on the screen's popup-menu window: that
  // surface owns the dialog blur region (PopupMenuWindow.dialogBlurRegion)
  // and click-outside close — Overlay.overlay on the settings surface has
  // neither. Reparents the popup while hosted and restores its parent on
  // `closed` (hostDialog unwinds the window side). The caller still opens the
  // popup afterwards; returns false when no popup window exists so the
  // caller's Overlay.overlay default still works.
  // popup → original parent, and popups that already carry the restore
  // handler. WeakMaps so destroyed popups can't pin entries.
  property var _hostedPopupParents: new WeakMap()
  property var _hostedPopupRestore: new WeakMap()

  // True when this screen's popup-menu window is showing a hosted modal
  // (file picker, colour dialog, icon picker, …).
  function screenHasDialog(screen) {
    var win = screen ? getPopupMenuWindow(screen) : null;
    return !!(win && win.hasDialog);
  }

  // Close that modal and return true. Esc uses this so the panel underneath
  // stays open. Returns false when there is nothing to close.
  function closeScreenDialog(screen) {
    var win = screen ? getPopupMenuWindow(screen) : null;
    if (!win || !win.dialogItem || !win.dialogItem.close)
      return false;
    win.dialogItem.close();
    return true;
  }

  function hostSettingsPopup(popup, screen) {
    var scr = screen || findFallbackScreen();
    var win = scr ? getPopupMenuWindow(scr) : null;
    if (!win || !popup)
      return false;
    if (!_hostedPopupParents.has(popup))
      _hostedPopupParents.set(popup, popup.parent);
    popup.parent = win.dialogParent;
    win.hostDialog(popup);
    if (!_hostedPopupRestore.has(popup)) {
      _hostedPopupRestore.set(popup, true);
      popup.closed.connect(function () {
        var prev = _hostedPopupParents.get(popup);
        if (prev) {
          popup.parent = prev;
          _hostedPopupParents.delete(popup);
        }
      });
    }
    return true;
  }

  // Returns a panel (loads it on-demand if not yet loaded)
  // By default, if panel not found on screen, tries other screens (favoring 0x0)
  // Pass fallback=false to disable this behavior
  function getPanel(name, screen, fallback = true) {
    if (!screen) {
      Logger.d("PanelService", "missing screen for getPanel:", name);
      // If no screen specified, return the first matching panel
      for (var key in registeredPanels) {
        if (key.startsWith(name + "-")) {
          return registeredPanels[key];
        }
      }
      return null;
    }

    var panelKey = `${name}-${screen.name}`;

    // Check if panel is already loaded
    if (registeredPanels[panelKey]) {
      return registeredPanels[panelKey];
    }

    // If fallback enabled, try to find panel on another screen
    if (fallback) {
      // First try the primary screen (0x0)
      var fallbackScreen = findFallbackScreen();
      if (fallbackScreen && fallbackScreen.name !== screen.name) {
        var fallbackKey = `${name}-${fallbackScreen.name}`;
        if (registeredPanels[fallbackKey]) {
          Logger.d("PanelService", "Panel fallback from", screen.name, "to", fallbackScreen.name);
          return registeredPanels[fallbackKey];
        }
      }

      // Try any other screen
      for (var key in registeredPanels) {
        if (key.startsWith(name + "-")) {
          Logger.d("PanelService", "Panel fallback to first available:", key);
          return registeredPanels[key];
        }
      }
    }

    Logger.w("PanelService", "Panel not found:", panelKey);
    return null;
  }

  // Check if a panel exists
  function hasPanel(name) {
    return name in registeredPanels;
  }

  // Returns the item's rect in screen coordinates (origin at the screen's
  // top-left). Works for items living in any of our layer windows: each
  // window that hosts taskbar items exposes its own `screenOrigin` property
  // (BarContentWindow, the fashion dock PanelWindow). The item is first
  // mapped into its window's content via mapToItem(null, …), then the
  // window origin is added. Returns null when the item can't be resolved.
  function screenRectOf(item, screen) {
    if (!item || !screen || typeof item.mapToItem !== "function") {
      return null;
    }
    var pos;
    try {
      pos = item.mapToItem(null, 0, 0);
    } catch (e) {
      return null;
    }
    // Layer-shell surfaces can't report their own position; the window's
    // origin is precomputed and exposed as `screenOrigin` on a content item
    // in the widget's parent chain (DockContent, the bar loader root).
    var ox = 0;
    var oy = 0;
    var found = false;
    var p = item;
    while (p) {
      if (p.screenOrigin !== undefined) {
        ox = p.screenOrigin.x;
        oy = p.screenOrigin.y;
        found = true;
        break;
      }
      p = p.parent;
    }
    if (!found) {
      var win = (item.Window && item.Window.window) ? item.Window.window : null;
      if (win && win.x !== undefined) {
        ox = win.x - (screen ? screen.x : 0);
        oy = win.y - (screen ? screen.y : 0);
      }
    }
    return Qt.rect(pos.x + ox, pos.y + oy, item.width, item.height);
  }

  // Edge of the shell surface hosting `item` — the bar window's edge for
  // status-bar widgets, the taskbar/dock edge for dock plugins (DESIGN
  // §3.13). Host windows mark their widget parent chain with `hostEdge` —
  // the same chain screenRectOf walks for `screenOrigin`. Returns "" when
  // the item is not inside a marked host surface.
  function surfaceEdgeOf(item) {
    var p = item;
    while (p) {
      if (p.hostEdge !== undefined && p.hostEdge !== "") {
        return p.hostEdge;
      }
      p = p.parent;
    }
    return "";
  }

  // Check if panels can be shown on a given screen (has a taskbar or allowPanelsOnScreenWithoutBar)
  function canShowPanelsOnScreen(screen) {
    const name = screen?.name || "";
    if (Settings.data.general.allowPanelsOnScreenWithoutBar) {
      return true;
    }
    return BarService.hasTaskbarOnScreen(name);
  }

  // Find a screen that can show panels
  function findScreenForPanels() {
    for (let i = 0; i < Quickshell.screens.length; i++) {
      if (canShowPanelsOnScreen(Quickshell.screens[i])) {
        return Quickshell.screens[i];
      }
    }
    return null;
  }

  // A Variants-injected modelData can hold a ShellScreen object the
  // compositor later replaced during output negotiation: the dead object
  // keeps its name but freezes width/height at a transient value, which
  // silently breaks every geometry binding that reads it. Geometry must
  // re-resolve the live object from Quickshell.screens by name — read the
  // list inside this function so callers' bindings keep tracking it.
  function liveScreen(screen) {
    if (!screen || !screen.name)
      return screen;
    const list = Quickshell.screens || [];
    for (let i = 0; i < list.length; i++) {
      if (list[i] && list[i].name === screen.name) {
        return list[i];
      }
    }
    return screen;
  }

  // Timer to switch from Exclusive to OnDemand keyboard focus on Hyprland
  Timer {
    id: keyboardInitTimer
    interval: 100
    repeat: false
    onTriggered: {
      root.isInitializingKeyboard = false;
    }
  }

  // Helper to keep only one panel open at any time
  function willOpenPanel(panel) {
    if (openedPanel && openedPanel !== panel) {
      // Move current panel to closing slot before closing it
      closingPanel = openedPanel;
      assignToSlot(1, closingPanel);
      openedPanel.close();
    }

    // Assign new panel to open slot
    openedPanel = panel;
    assignToSlot(0, panel);

    // Start keyboard initialization period (for Hyprland workaround)
    if (panel && panel.exclusiveKeyboard) {
      isInitializingKeyboard = true;
      keyboardInitTimer.restart();
    }

    // emit signal
    willOpen();
  }

  // ==================== Launcher API ====================
  // The DDE launcher (fullscreen/mini layer surfaces) owns its own open state
  // through LauncherState (DESIGN §3.4); these are thin forwards kept for the
  // IPC and widget call sites.

  function openLauncher(screen) {
    LauncherState.open(screen);
  }

  function toggleLauncher(screen) {
    LauncherState.toggle(screen);
  }

  function isLauncherOpen(screen) {
    return LauncherState.isOpen(screen);
  }

  function getLauncherSearchText(screen) {
    var model = LauncherState.modelForScreen(screen);
    return model ? model.searchText : "";
  }

  function setLauncherSearchText(screen, text) {
    var model = LauncherState.modelForScreen(screen);
    if (model)
      model.setSearchText(text);
  }

  function openLauncherWithSearch(screen, searchText) {
    LauncherState.openWithSearch(screen, searchText);
  }

  function closeLauncher(screen) {
    LauncherState.close(screen);
  }

  // Close any open panel (for general use)
  function closePanel() {
    if (openedPanel && openedPanel.close) {
      openedPanel.close();
    }
  }

  function closedPanel(panel) {
    if (openedPanel && openedPanel === panel) {
      openedPanel = null;
      assignToSlot(0, null);
    }

    if (closingPanel && closingPanel === panel) {
      closingPanel = null;
      assignToSlot(1, null);
    }

    // Reset keyboard init state
    isInitializingKeyboard = false;
    keyboardInitTimer.stop();

    // emit signal
    didClose();
  }

  // Close panels when compositor overview opens (if setting is enabled)
  Connections {
    target: CompositorService
    enabled: Settings.data.bar.hideOnOverview

    function onOverviewActiveChanged() {
      if (CompositorService.overviewActive && root.openedPanel) {
        root.openedPanel.close();
      }
    }
  }
}
