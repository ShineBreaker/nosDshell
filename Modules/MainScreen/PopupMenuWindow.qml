import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.Debug
import qs.Services.UI
import qs.Widgets

// Generic full-screen popup window for menus and context menus
// This is a top-level PanelWindow (sibling to MainScreen, not nested inside it)
// Provides click-outside-to-close functionality for any popup content
// Loads TrayMenu by default but can show context menus via showContextMenu()
PanelWindow {
  id: root

  required property ShellScreen screen
  property string windowType: "popupmenu"  // Used for namespace and registration

  // Content item to display (set by the popup that uses this window)
  property var contentItem: null

  // Expose the trayMenu Loader directly (for backward compatibility)
  readonly property alias trayMenuLoader: trayMenuLoader

  // Dynamic context menu callback for items in other windows (e.g., desktop widgets)
  property var dynamicMenuCallback: null

  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true
  visible: false
  color: "transparent"

  // Use Top layer for proper event handling, but on labwc use Bottom
  // to avoid stealing input from popups while still catching outside clicks.
  // However, when a dialog is open, always use Top so dialogs appear above apps.
  WlrLayershell.layer: (CompositorService.isLabwc && !hasDialog) ? WlrLayer.Bottom : WlrLayer.Top
  WlrLayershell.keyboardFocus: hasDialog ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  WlrLayershell.namespace: "nosdshell-" + windowType + "-" + (screen?.name || "unknown")
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  // The currently open modal dialog (created into dialogContainer by
  // BarService/DesktopWidgetRegistry). hasDialog is derived — callers assign
  // dialogItem, never hasDialog, so the window state can't drift from the
  // item actually on screen.
  property var dialogItem: null
  readonly property bool hasDialog: dialogItem !== null

  // Frosted-glass behind the open dialog: settings popups render inside
  // this surface, so the blur region rides the same BackgroundEffect path
  // the panels/dock use (DESIGN §1.2).
  BackgroundEffect.blurRegion: dialogBlurRegion.region
  NSurfaceRegion {
    id: dialogBlurRegion
    // Dialogs opened here are Qt Quick Popups — QObject, not Item — so the
    // tracked rect must be their contentItem (Qt Quick renders the popup at
    // its x/y through that child).
    trackedItem: {
      const d = root.dialogItem;
      if (!d)
        return null;
      return (d instanceof Item) ? d : (d.contentItem || null);
    }
    radius: Style.radiusWindow
    activeWhen: Color.blurActive && root.dialogItem !== null
  }

  // Register with PanelService so widgets can find this window, and as a
  // debug root so `debug find/tree` can reach dialogs rendered inside it.
  property string _dbgName: ""
  Component.onCompleted: {
    objectName = "popupMenuWindow-" + (screen?.name || "unknown");
    PanelService.registerPopupMenuWindow(screen, root);
    if (screen && screen.name) {
      root._dbgName = "popupMenuWindow-" + screen.name;
      // Register the window's real content item — root.contentItem is this
      // file's own popup-content property and shadows QQuickWindow.contentItem;
      // dialogContainer.parent reaches the actual scene root so debug
      // tree/find covers dialogs created into dialogContainer.
      DebugService.registerRoot(root._dbgName, dialogContainer.parent);
    }
  }

  Component.onDestruction: {
    PanelService.unregisterPopupMenuWindow(screen);
    if (root._dbgName !== "")
      DebugService.unregisterRoot(root._dbgName);
  }

  // Load TrayMenu as the default content
  Loader {
    id: trayMenuLoader
    source: Quickshell.shellDir + "/Modules/Bar/Extras/TrayMenu.qml"
    onLoaded: {
      if (item) {
        item.screen = root.screen;
        // Set the loaded item as default content
        root.contentItem = item;
      }
    }
  }

  // Dynamic context menu - created as child of this window (Top layer) so input works correctly
  // Used for items in other windows like desktop widgets (bottom layer)
  NPopupContextMenu {
    id: dynamicMenu
    visible: false
    screen: root.screen
    minWidth: 180

    onTriggered: (action, item) => {
                   if (root.dynamicMenuCallback) {
                     // Callback returns true if it will handle closing (e.g., opening a dialog)
                     var handled = root.dynamicMenuCallback(action);
                     if (!handled) {
                       root.close();
                     }
                   } else {
                     root.close();
                   }
                 }
  }

  // Hold the window mapped briefly so popup content can play its own
  // fade-out before the surface goes away (TrayMenu/NPopupContextMenu run
  // ~motionPopupOut).
  Timer {
    id: closeTimer
    interval: Style.motionPopupOut + 40
    onTriggered: {
      root.visible = false;
      root._finishClose();
    }
  }

  function open() {
    closeTimer.stop();
    visible = true;
    BarService.popupOpen = true;
  }

  // Host a dialog Popup on this surface: installs it as dialogItem (which
  // switches on the dialog blur region and keyboard focus) and opens the
  // window. The caller keeps object ownership — wire its own `closed` for
  // destroy/state cleanup; this handler only unwinds the window side. Connect
  // it before the caller's own `closed` handlers so dialogItem clears before
  // the object is destroyed.
  function hostDialog(dialog) {
    dialogItem = dialog;
    open();
    dialog.closed.connect(function () {
      if (dialogItem === dialog)
        dialogItem = null;
      close();
    });
  }

  // Show a context menu (temporarily replaces TrayMenu as content)
  function showContextMenu(menu) {
    if (menu) {
      contentItem = menu;
      open();
    }
  }

  // Show a dynamic context menu with model and callback at screen coordinates
  // Used for items in other window layers (e.g., desktop widgets in bottom layer)
  // variant: "dark" (default) or "light" (DDE light menu, e.g. the dock settings menu)
  function showDynamicContextMenu(model, screenX, screenY, callback, variant) {
    dynamicMenu.model = model;
    dynamicMenu.variant = variant || "dark";
    dynamicMenuCallback = callback;

    // Use the anchor point item for positioning at absolute coordinates
    dynamicMenu.anchorItem = anchorPoint;
    anchorPoint.x = screenX;
    anchorPoint.y = screenY;

    contentItem = dynamicMenu;
    dynamicMenu.visible = true;
    open();
    return dynamicMenu;
  }

  // Invisible anchor point for dynamic menu positioning
  Item {
    id: anchorPoint
    width: 1
    height: 1
  }

  // Hide just the dynamic menu without closing the popup window
  // Used when transitioning from context menu to a dialog
  function hideDynamicMenu() {
    dynamicMenu.visible = false;
  }

  property bool _closing: false

  function close() {
    if (!visible || _closing || closeTimer.running)
      return;
    _closing = true;
    BarService.popupOpen = false;
    // A hosted dialog must be closed with the window — a Popup object survives
    // the surface unmapping and would otherwise leak and reappear on the next
    // open(). Keep dialogItem until its `closed` fires so the blur region rides
    // the exit fade; the re-entrant close() that fires is absorbed by _closing.
    if (dialogItem && typeof dialogItem.close === "function") {
      dialogItem.close();
    }
    // Call close/hide method on current content — it fades out, then the
    // timer unmaps this window once the animation has played.
    if (contentItem) {
      if (typeof contentItem.hideMenu === "function") {
        contentItem.hideMenu();
      } else if (typeof contentItem.close === "function") {
        contentItem.close();
      }
    }
    closeTimer.restart();
    _closing = false;
  }

  function _finishClose() {
    // A dialog whose exit transition outlived the surface: force it closed so
    // its `closed` handlers run and callers destroy it — a Popup cannot outlive
    // the hidden window it renders on.
    if (dialogItem) {
      var d = dialogItem;
      dialogItem = null;
      try {
        d.visible = false;
      } catch (e) {}
    }
    // Hide dynamic menu
    dynamicMenu.visible = false;
    dynamicMenu.variant = "dark";
    dynamicMenuCallback = null;
    // Restore TrayMenu as default content
    if (trayMenuLoader.item) {
      contentItem = trayMenuLoader.item;
    }
  }

  // Full-screen click catcher - click anywhere outside content closes the window
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: root.close()
  }

  // Container for dialogs that need a full-screen Item parent (e.g., Qt Popup)
  Item {
    id: dialogContainer
    anchors.fill: parent
  }

  // Expose the dialog container for external use
  readonly property alias dialogParent: dialogContainer
}
