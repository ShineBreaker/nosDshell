import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.Compositor
import qs.Services.Debug
import qs.Services.UI
import qs.Widgets

PopupWindow {
  id: root

  property var toplevel: null
  property var appData: null
  property Item anchorItem: null
  property ShellScreen targetScreen: null

  property string menuMode: "app" // "app" or "launcher"
  property string launcherWidgetSection: ""
  property int launcherWidgetIndex: -1
  property var launcherWidgetSettings: ({})

  property bool hovered: menuHoverHandler.hovered
  property var onAppClosed: null // Callback function for when an app is closed
  property bool canAutoClose: false

  // The fashion dock feeds Quickshell Toplevel objects (activate()/close());
  // the efficient taskbar feeds CompositorService backend windows, which are
  // plain data — focus/close route through the service instead and liveness
  // filtering against ToplevelManager is skipped (the taskbar model already
  // maintains it).
  property bool backendWindows: false

  // Track which menu item is hovered
  property int hoveredItem: -1 // -1: none, otherwise the index of the item in `items`

  property var items: []

  signal requestClose

  property real menuContentWidth: 160
  property real menuMinWidth: 120
  property real menuMaxWidth: 360
  property real menuMaxHeight: Math.max(180, Math.min(420, Math.round((targetScreen ? targetScreen.height : 600) * 0.3)))
  property int separatorCompactHeight: Style.borderS + Style.margin2S
  property string forcedGroupMenuMode: ""
  readonly property int separatorIndex: {
    for (let i = 0; i < root.items.length; i++) {
      if (root.items[i] && root.items[i].separator === true)
        return i;
    }
    return -1;
  }
  readonly property bool splitExtendedLayout: separatorIndex >= 0
  readonly property var scrollItems: splitExtendedLayout ? root.items.slice(0, separatorIndex) : root.items
  readonly property var fixedItems: splitExtendedLayout ? root.items.slice(separatorIndex + 1) : []
  readonly property real menuInnerHeight: Math.max(0, bodyHeight - Style.margin2M - (arrowEdge === "top" || arrowEdge === "bottom" ? Style.popupArrowHeight : 0))
  readonly property real fixedActionsHeight: listHeight(fixedItems)
  readonly property real separatorBlockHeight: splitExtendedLayout ? separatorCompactHeight : 0
  readonly property real scrollAreaHeight: splitExtendedLayout ? Math.max(0, menuInnerHeight - fixedActionsHeight - separatorBlockHeight) : menuInnerHeight
  readonly property bool listOverflowing: menuFlick && menuFlick.contentHeight > menuFlick.height
  readonly property real menuBodyHeight: {
    if (splitExtendedLayout) {
      return listHeight(scrollItems) + separatorBlockHeight + fixedActionsHeight;
    }
    return listHeight(root.items);
  }

  readonly property real bodyWidth: menuContentWidth + Style.margin2M + (arrowEdge === "left" || arrowEdge === "right" ? Style.popupArrowHeight : 0)
  implicitWidth: bodyWidth + 2 * shadowInset
  readonly property real bodyHeight: Math.min(menuBodyHeight + Style.margin2M, menuMaxHeight) + (arrowEdge === "top" || arrowEdge === "bottom" ? Style.popupArrowHeight : 0)
  implicitHeight: bodyHeight + 2 * shadowInset

  // Room around the body for the popup shadow (DESIGN §1.6); the input
  // region below keeps it click-through.
  readonly property int shadowInset: Style.popupShadowInset
  mask: Region {
    item: reveal
  }
  color: "transparent"
  visible: false

  // Blur only the opaque body — without a client region niri's popups rule
  // blurs the whole surface rect and the arrow's transparent margins render
  // as a stray blurred band beside the card (NSurfaceRegion, NArrowRect).
  BackgroundEffect.blurRegion: menuBlurRegion.region
  NSurfaceRegion {
    id: menuBlurRegion
    trackedItem: menuBody.bodyItem
    radius: menuBody.radius
    activeWhen: Colors.blurActive
    // The reveal slides the card inside the surface — feed the sentinel the
    // animated distance so the region follows each frame.
    watch: reveal.revealDistance
  }

  // Hidden text element for measuring text width
  NText {
    id: textMeasure
    visible: false
    pointSize: Style.fontSizeS
    family: "Sans Serif" // Match your NText font if different
    wrapMode: Text.NoWrap
    elide: Text.ElideNone
  }

  // Calculate the maximum width needed for all menu items
  function calculateMenuWidth() {
    let maxWidth = 0; // Start with 0, we'll apply minimum later
    if (root.items && root.items.length > 0) {
      for (let i = 0; i < root.items.length; i++) {
        const item = root.items[i];
        if (item && item.text) {
          // Calculate width: margins + icon (if present) + spacing + text width
          let itemWidth = Style.menuItemPadding * 2; // left and right padding

          if (item.icon && item.icon !== "") {
            itemWidth += Style.fontSizeL + Style.marginS; // icon + spacing
          }

          // Measure actual text width
          textMeasure.text = item.text;
          const textWidth = textMeasure.contentWidth;
          itemWidth += textWidth;

          if (itemWidth > maxWidth) {
            maxWidth = itemWidth;
          }
        }
      }
    }
    // Keep menu readable without allowing extremely wide labels.
    menuContentWidth = Math.max(menuMinWidth, Math.min(menuMaxWidth, Math.ceil(maxWidth)));
  }

  function getCurrentAppId() {
    return appData?.appId || toplevel?.appId || "";
  }

  function getValidToplevels() {
    const source = appData?.toplevels && appData.toplevels.length > 0 ? appData.toplevels : (toplevel ? [toplevel] : []);
    if (backendWindows)
      return source.filter(window => window);
    if (!ToplevelManager || !ToplevelManager.toplevels)
      return [];
    const allToplevels = ToplevelManager.toplevels.values || [];
    return source.filter(window => window && allToplevels.includes(window));
  }

  function getPrimaryToplevel() {
    const windows = getValidToplevels();
    if (windows.length === 0)
      return null;
    if (backendWindows)
      return windows[0];
    if (ToplevelManager && ToplevelManager.activeToplevel && windows.includes(ToplevelManager.activeToplevel))
      return ToplevelManager.activeToplevel;
    return windows[0];
  }

  function isItemActionable(index) {
    if (index < 0 || index >= root.items.length)
      return false;
    const item = root.items[index];
    return item && typeof item.action === "function";
  }

  function rowHeightForItem(item) {
    // DDE menu rows: font height + 8; separators are 6px grooves
    return item && item.separator === true ? Style.marginS : Math.round(Style.fontSizeS * 1.33) + 8;
  }

  function listHeight(items) {
    let total = 0;
    if (!items)
      return total;
    for (let i = 0; i < items.length; i++) {
      total += rowHeightForItem(items[i]);
    }
    return total;
  }

  function initItems() {
    if (menuMode === "launcher") {
      root.items = [
            {
              "icon": "cpu",
              "text": I18n.tr("dock-menu.task-manager"),
              "action": function () {
                CompositorService.launchInTerminal(Settings.data.dock.taskManagerCommand);
                closeAndReset();
              }
            },
            {
              "icon": "adjustments",
              "text": I18n.tr("actions.dock-settings"),
              "action": function () {
                handleDockSettings();
              }
            },
            {
              "icon": "adjustments",
              "text": I18n.tr("actions.launcher-settings"),
              "action": function () {
                handleLauncherSettings();
              }
            }
          ];
      calculateMenuWidth();
      return;
    }

    const windows = getValidToplevels();
    const primaryToplevel = getPrimaryToplevel();
    const appId = getCurrentAppId();
    const isRunning = windows.length > 0;
    const isPinned = isAppPinned(appId);
    const grouped = Settings.data.dock.groupApps && windows.length > 1;
    const rawGroupMenuMode = forcedGroupMenuMode || Settings.data.dock.groupContextMenuMode || "extended";
    const menuModeForGroup = grouped ? ((rawGroupMenuMode === "list" || rawGroupMenuMode === "extended") ? rawGroupMenuMode : "extended") : "single";

    var next = [];

    if (!grouped || menuModeForGroup === "single") {
      // DDE/Windows: "open" launches a new instance — for a pinned app that
      // is not running it is the only way to start it from the menu.
      if (appId) {
        next.push({
                    "icon": "rocket",
                    "text": I18n.tr("common.open"),
                    "action": function () {
                      handleOpen(appId);
                    }
                  });
      }

      if (isRunning) {
        next.push({
                    "icon": "eye",
                    "text": I18n.tr("common.focus"),
                    "action": function () {
                      handleFocus(primaryToplevel);
                    }
                  });
      }

      next.push({
                  "icon": !isPinned ? "pin" : "unpin",
                  "text": !isPinned ? I18n.tr("common.pin") : I18n.tr("common.unpin"),
                  "action": function () {
                    handlePin(appId);
                  }
                });

      if (isRunning) {
        next.push({
                    "icon": "close",
                    "text": I18n.tr("common.close"),
                    "action": function () {
                      handleClose(primaryToplevel);
                    }
                  });
      }
    } else {
      windows.forEach((window, index) => {
                        const windowTitle = (window.title && window.title.trim() !== "") ? window.title : (appId || ("Window " + (index + 1)));
                        const windowActive = backendWindows ? window.isFocused === true : window === ToplevelManager?.activeToplevel;
                        next.push({
                                    "icon": windowActive ? "circle-filled" : "square-rounded",
                                    "text": windowTitle,
                                    "action": function () {
                                      handleFocus(window);
                                    }
                                  });
                      });

      if (menuModeForGroup === "extended") {
        next.push({
                    "separator": true
                  });
        if (appId) {
          next.push({
                      "icon": "rocket",
                      "text": I18n.tr("common.open"),
                      "action": function () {
                        handleOpen(appId);
                      }
                    });
        }
        next.push({
                    "icon": "eye",
                    "text": I18n.tr("common.focus"),
                    "action": function () {
                      handleFocus(primaryToplevel);
                    }
                  });
        next.push({
                    "icon": !isPinned ? "pin" : "unpin",
                    "text": !isPinned ? I18n.tr("common.pin") : I18n.tr("common.unpin"),
                    "action": function () {
                      handlePin(appId);
                    }
                  });
        next.push({
                    "icon": "close",
                    "text": I18n.tr("common.close-all"),
                    "action": function () {
                      handleCloseAll(windows);
                    }
                  });
      }
    }

    // Keep grouped list mode as a clean window switcher.
    const canAddDesktopActions = !grouped || menuModeForGroup === "extended";

    // Create a menu entry for each app-specific action defined in its .desktop file
    if (canAddDesktopActions && typeof DesktopEntries !== 'undefined' && DesktopEntries.byId && appId) {
      const entry = (DesktopEntries.heuristicLookup) ? DesktopEntries.heuristicLookup(appId) : DesktopEntries.byId(appId);
      if (entry != null) {
        entry.actions.forEach(function (action) {
          next.push({
                      "icon": "chevron-right",
                      "text": action.name,
                      "action": function () {
                        if (action.command && action.command.length > 0) {
                          Quickshell.execDetached(action.command);
                        } else if (action.execute) {
                          action.execute();
                        }
                      }
                    });
        });
      }
    }

    root.items = next;
    // Force width recalculation when items change
    calculateMenuWidth();
  }

  // Helper functions forwarded to the shared AppIdMatcher singleton; the dock
  // menu pins desktop entry IDs and checks pins through desktop-entry
  // resolution (strong match — the taskbar's identical call; the weak direct
  // compare missed StartupWMClass != .desktop filename pairs).
  function isAppPinned(appId) {
    return AppIdMatcher.isAppPinned(appId, {
                                      resolveEntry: true
                                    });
  }

  function toggleAppPin(appId) {
    AppIdMatcher.toggleAppPin(appId, {
                                useDesktopEntryId: true
                              });
  }

  // Dock position for context menu placement
  property string dockPosition: "bottom"

  // Arrow on the menu edge facing the dock item (DESIGN §3.3 arrowed dark menu)
  readonly property string arrowEdge: dockPosition === "top" ? "top" : dockPosition === "bottom" ? "bottom" : dockPosition === "left" ? "left" : "right"
  // Arrow tip points at the item center along the arrow edge
  readonly property real _arrowPos: {
    if (!anchorItem)
      return -1;
    if (arrowEdge === "top" || arrowEdge === "bottom")
      return anchorItem.width / 2 - _bodyAnchorX;
    if (arrowEdge === "left" || arrowEdge === "right")
      return anchorItem.height / 2 - _bodyAnchorY;
    return -1;
  }

  anchor.item: anchorItem
  // The window carries a shadowInset margin on every side so the §1.6
  // shadow has room to render; the anchor math above places the body, the
  // window is offset by the inset, and the compositor must not slide or
  // flip it (that would move the body by up to the inset).
  anchor.adjustment: PopupAdjustment.None
  // Position menu on the opposite side of the dock, arrow tip Style.popupGap
  // (2 px) from the item edge
  readonly property real _bodyAnchorX: {
    if (!anchorItem)
      return 0;
    switch (dockPosition) {
    case "left":
      return anchorItem.width + Style.popupGap; // Open to right of dock
    case "right":
      return -bodyWidth - Style.popupGap; // Open to left of dock
    default:
      return (anchorItem.width - bodyWidth) / 2; // Center horizontally
    }
  }
  anchor.rect.x: _bodyAnchorX - shadowInset
  readonly property real _bodyAnchorY: {
    if (!anchorItem)
      return 0;
    switch (dockPosition) {
    case "top":
      return anchorItem.height + Style.popupGap; // Open below dock
    case "bottom":
      return -bodyHeight - Style.popupGap; // Open above dock (default)
    case "left":
    case "right":
      return (anchorItem.height - bodyHeight) / 2; // Center vertically
    default:
      return -bodyHeight - Style.popupGap;
    }
  }
  anchor.rect.y: _bodyAnchorY - shadowInset

  function show(item, toplevelData, screen, groupModeOverride) {
    if (!item) {
      return;
    }

    // Cancel a pending close so reopening replays the enter animation and
    // doesn't race the hide timer.
    hideTimer.stop();
    _closing = false;
    _resetOnHide = false;

    // First hide completely
    visible = false;

    // Then set up new data
    anchorItem = item;
    if (toplevelData && typeof toplevelData === "object" && (toplevelData.appId !== undefined || toplevelData.toplevels !== undefined)) {
      appData = toplevelData;
      toplevel = toplevelData.toplevel || null;
    } else {
      appData = toplevelData ? {
                                 "appId": toplevelData.appId,
                                 "toplevel": toplevelData,
                                 "toplevels": toplevelData ? [toplevelData] : []
                               } : null;
      toplevel = toplevelData;
    }
    targetScreen = screen || null;
    forcedGroupMenuMode = groupModeOverride || "";
    initItems();

    visible = true;
    canAutoClose = false;
    gracePeriodTimer.restart();
  }

  // Helper function to determine which menu item is under the mouse
  function getHoveredItem(mouseY) {
    const startY = Style.marginM;
    const localY = mouseY - startY;

    if (localY < 0)
      return -1;

    function findIndexInList(items, relativeY, baseIndex) {
      let offset = 0;
      for (let i = 0; i < items.length; i++) {
        const h = rowHeightForItem(items[i]);
        if (relativeY >= offset && relativeY < offset + h)
          return baseIndex + i;
        offset += h;
      }
      return -1;
    }

    if (splitExtendedLayout) {
      if (localY < scrollAreaHeight) {
        return findIndexInList(scrollItems, localY + (menuFlick ? menuFlick.contentY : 0), 0);
      }
      if (localY < scrollAreaHeight + separatorBlockHeight) {
        return -1;
      }
      return findIndexInList(fixedItems, localY - scrollAreaHeight - separatorBlockHeight, separatorIndex + 1);
    } else {
      return findIndexInList(scrollItems, localY + (menuFlick ? menuFlick.contentY : 0), 0);
    }
  }

  function fixedItemGlobalIndex(localIndex) {
    if (!splitExtendedLayout)
      return localIndex;
    return separatorIndex + 1 + localIndex;
  }

  function isScrollableHovered(mouseY) {
    const localY = mouseY - Style.marginM;
    return localY >= 0 && localY < scrollAreaHeight;
  }

  function onWheelScroll(deltaY) {
    if (!menuFlick || menuFlick.contentHeight <= menuFlick.height)
      return;
    const nextY = menuFlick.contentY - deltaY;
    menuFlick.contentY = Math.max(0, Math.min(nextY, menuFlick.contentHeight - menuFlick.height));
  }

  function resetMenuState() {
    root.items.length = 0;
    root.appData = null;
    root.toplevel = null;
    root.forcedGroupMenuMode = "";
    menuContentWidth = menuMinWidth;
    hoveredItem = -1;
    if (menuFlick)
      menuFlick.contentY = 0;
  }

  // Fade-out before the popup surface unmaps (DESIGN §1.7): _closing drives
  // the reveal's exit, the timer then flips visible and applies the deferred
  // state reset for hide().
  property bool _closing: false
  property bool _resetOnHide: false
  // visible stays true through the exit fade; use shown for open/closed logic
  readonly property bool shown: visible && !_closing

  Timer {
    id: hideTimer
    interval: Style.motionPopupOut
    repeat: false
    onTriggered: {
      root.visible = false;
      root._closing = false;
      if (root._resetOnHide) {
        root._resetOnHide = false;
        root.resetMenuState();
      }
    }
  }

  function _startHide(reset) {
    if (_closing) {
      // A second hide() while the exit plays must still reset afterwards.
      _resetOnHide = _resetOnHide || reset;
      return;
    }
    _closing = true;
    _resetOnHide = reset;
    hideTimer.restart();
  }

  function hide() {
    _startHide(true);
  }

  function hideWithoutReset() {
    _startHide(false);
  }

  function closeAndReset() {
    hide();
    root.requestClose();
  }

  function handleFocus(targetToplevel) {
    if (root.backendWindows) {
      if (targetToplevel)
        CompositorService.focusWindow(targetToplevel);
    } else if (targetToplevel?.activate) {
      targetToplevel.activate();
    }
    closeAndReset();
  }

  function handlePin(appId) {
    if (appId) {
      root.toggleAppPin(appId);
    }
    Qt.callLater(() => closeAndReset());
  }

  function handleOpen(appId) {
    if (appId) {
      const app = ThemeIcons.findAppEntry(appId);
      if (app) {
        CompositorService.launchDesktopEntry(app);
      } else {
        Logger.w("DockMenu", `Could not find desktop entry for app: ${appId}`);
      }
    }
    closeAndReset();
  }

  function handleClose(targetToplevel) {
    if (root.backendWindows) {
      if (targetToplevel) {
        CompositorService.closeWindow(targetToplevel);
        if (root.onAppClosed && typeof root.onAppClosed === "function") {
          Qt.callLater(root.onAppClosed);
        }
      }
      closeAndReset();
      return;
    }
    const isValidToplevel = targetToplevel && ToplevelManager && ToplevelManager.toplevels.values.includes(targetToplevel);

    if (isValidToplevel && targetToplevel.close) {
      targetToplevel.close();
      if (root.onAppClosed && typeof root.onAppClosed === "function") {
        Qt.callLater(root.onAppClosed);
      }
    }
    closeAndReset();
  }

  function handleCloseAll(windows) {
    windows.forEach(window => {
                      if (root.backendWindows) {
                        if (window)
                        CompositorService.closeWindow(window);
                      } else if (window && ToplevelManager && ToplevelManager.toplevels.values.includes(window) && window.close) {
                        window.close();
                      }
                    });
    if (root.onAppClosed && typeof root.onAppClosed === "function") {
      Qt.callLater(root.onAppClosed);
    }
    closeAndReset();
  }

  function handleLauncherSettings() {
    if (targetScreen)
      SettingsPanelService.openToTab(SettingsPanel.Tab.Launcher, -1, targetScreen);
    closeAndReset();
  }

  function handleDockSettings() {
    if (targetScreen)
      SettingsPanelService.openToTab(SettingsPanel.Tab.Dock, -1, targetScreen);
    closeAndReset();
  }

  function handleLauncherWidgetSettings() {
    if (targetScreen && launcherWidgetSection && launcherWidgetIndex >= 0) {
      BarService.openWidgetSettings(targetScreen, launcherWidgetSection, launcherWidgetIndex, "Launcher", launcherWidgetSettings || {});
    }
    closeAndReset();
  }

  // Short delay to ignore spurious events
  Timer {
    id: gracePeriodTimer
    interval: 1500
    repeat: false
    onTriggered: {
      root.canAutoClose = true;
      if (!menuHoverHandler.hovered) {
        closeTimer.start();
      }
    }
  }

  Timer {
    id: closeTimer
    interval: 500
    repeat: false
    running: false
    onTriggered: {
      root.hideWithoutReset();
    }
  }

  // Reveal (DESIGN §1.7): background, shadow and menu content fade and
  // slide together along the arrow edge.
  NPopupReveal {
    id: reveal
    inset: root.shadowInset

    active: root.visible
    closing: root._closing
    edge: root.arrowEdge

    NArrowRect {
      id: menuBody
      anchors.fill: parent
      arrowEdge: root.arrowEdge
      arrowPosition: root._arrowPos
      fillColor: Colors.popupShell
      radius: Style.radiusPopup
      borderColor: Colors.borderShell
      borderWidth: Style.borderS
      shadow: Style.shadowPopup

      HoverHandler {
        id: menuHoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
          if (hovered) {
            closeTimer.stop();
          } else {
            root.hoveredItem = -1;
            if (root.canAutoClose) {
              closeTimer.start();
            }
          }
        }
      }

      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
                   if (!root.isScrollableHovered(event.y))
                   return;
                   const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2;
                   root.onWheelScroll(delta);
                   event.accepted = true;
                 }
      }

      Flickable {
        id: menuFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Style.marginM + (root.arrowEdge === "left" ? Style.popupArrowHeight : 0)
        anchors.rightMargin: Style.marginM + (root.arrowEdge === "right" ? Style.popupArrowHeight : 0)
        anchors.topMargin: Style.marginM + (root.arrowEdge === "top" ? Style.popupArrowHeight : 0)
        height: root.scrollAreaHeight
        clip: true
        contentWidth: width
        contentHeight: scrollColumn.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {
          id: menuScrollBar
          policy: ScrollBar.AsNeeded
          visible: root.listOverflowing
          interactive: true
          hoverEnabled: true
        }

        Column {
          id: scrollColumn
          width: menuFlick.width
          spacing: 0

          Repeater {
            model: root.scrollItems

            Rectangle {
              // objectName exposes the row to `debug tree dockmenu-*`:
              // label text is readable in the dump and click targets can be
              // computed from the row rect.
              objectName: "dockMenuItem:" + (modelData && modelData.text ? modelData.text : "separator")
              readonly property bool isSeparator: modelData && modelData.separator === true
              width: scrollColumn.width
              height: root.rowHeightForItem(modelData)
              color: (!isSeparator && root.hoveredItem === index) ? Colors.accent : "transparent"
              radius: Style.radiusRow

              // Separator: DDE two-line groove (dark over light, inset 4)
              NDivider {
                variant: "ddeGroove"
                visible: parent.isSeparator
                anchors.centerIn: parent
                width: parent.width - Style.margin2XS
              }

              Row {
                id: rowLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.menuItemPadding
                anchors.rightMargin: Style.menuItemPadding
                spacing: Style.marginS
                visible: !isSeparator

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeL
                  color: root.hoveredItem === index ? Colors.onAccent : Colors.onShellSecondary
                  visible: icon !== ""
                  anchors.verticalCenter: parent.verticalCenter
                }

                NText {
                  text: modelData.text
                  pointSize: Style.fontSizeS
                  color: root.hoveredItem === index ? Colors.onAccent : Colors.onShell
                  anchors.verticalCenter: parent.verticalCenter
                  width: rowLayout.width - ((modelData.icon && modelData.icon !== "") ? (Style.fontSizeL + Style.marginS) : 0)
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                enabled: !parent.isSeparator && root.isItemActionable(index)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                onEntered: {
                  root.hoveredItem = index;
                }

                onExited: {
                  if (root.hoveredItem === index) {
                    root.hoveredItem = -1;
                  }
                }

                onClicked: {
                  if (root.isItemActionable(index)) {
                    root.items[index].action.call();
                  }
                }
              }
            }
          }
        }
      }

      // DDE two-line groove (dark over light)
      NDivider {
        id: separator
        variant: "ddeGroove"
        visible: root.splitExtendedLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: menuFlick.bottom
        anchors.leftMargin: Style.marginXS
        anchors.rightMargin: Style.marginXS
        anchors.topMargin: Style.marginS
      }

      Column {
        id: fixedColumn
        visible: root.splitExtendedLayout && root.fixedItems.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.marginM + (root.arrowEdge === "left" ? Style.popupArrowHeight : 0)
        anchors.rightMargin: Style.marginM + (root.arrowEdge === "right" ? Style.popupArrowHeight : 0)
        anchors.topMargin: Style.marginS
        anchors.bottomMargin: Style.marginM + (root.arrowEdge === "bottom" ? Style.popupArrowHeight : 0)
        anchors.top: separator.bottom
        spacing: 0

        Repeater {
          model: root.fixedItems

          Rectangle {
            id: fixedItemRect
            objectName: "dockMenuItem:" + (modelData && modelData.text ? modelData.text : "separator")
            readonly property int globalIndex: root.fixedItemGlobalIndex(index)
            width: fixedColumn.width
            height: root.rowHeightForItem(modelData)
            color: root.hoveredItem === globalIndex ? Colors.accent : "transparent"
            radius: Style.radiusRow

            Row {
              id: fixedRowLayout
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.menuItemPadding
              anchors.rightMargin: Style.menuItemPadding
              spacing: Style.marginS

              NIcon {
                icon: modelData.icon
                pointSize: Style.fontSizeL
                color: root.hoveredItem === fixedItemRect.globalIndex ? Colors.onAccent : Colors.onShellSecondary
                visible: icon !== ""
                anchors.verticalCenter: parent.verticalCenter
              }

              NText {
                text: modelData.text
                pointSize: Style.fontSizeS
                color: root.hoveredItem === fixedItemRect.globalIndex ? Colors.onAccent : Colors.onShell
                anchors.verticalCenter: parent.verticalCenter
                width: fixedRowLayout.width - ((modelData.icon && modelData.icon !== "") ? (Style.fontSizeL + Style.marginS) : 0)
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              enabled: root.isItemActionable(parent.globalIndex)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton

              onEntered: {
                root.hoveredItem = parent.globalIndex;
              }

              onExited: {
                if (root.hoveredItem === parent.globalIndex) {
                  root.hoveredItem = -1;
                }
              }

              onClicked: {
                if (root.isItemActionable(parent.globalIndex)) {
                  root.items[parent.globalIndex].action.call();
                }
              }
            }
          }
        }
      }
    }
  }

  // Debug forensics: the menu rows live in their own PopupWindow surface, so
  // neither the bar nor the dock `debug tree` reaches them. Registering the
  // menu body exposes the rows as `debug tree/hit dockmenu-…` — coordinates
  // are popup-window-local.
  property string _dbgName: ""
  Component.onCompleted: {
    root._dbgName = "dockmenu-" + (menuMode !== "" ? menuMode : "app") + "-" + dockPosition;
    DebugService.registerRoot(root._dbgName, menuBody);
  }
  Component.onDestruction: {
    if (root._dbgName !== "")
      DebugService.unregisterRoot(root._dbgName);
  }
}
