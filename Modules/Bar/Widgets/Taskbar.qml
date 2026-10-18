import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Modules.Dock
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  property bool hasWindow: false
  readonly property string hideMode: (widgetSettings.hideMode !== undefined) ? widgetSettings.hideMode : widgetMetadata.hideMode
  readonly property bool colorizeIcons: (widgetSettings.colorizeIcons !== undefined) ? widgetSettings.colorizeIcons : widgetMetadata.colorizeIcons
  readonly property bool onlySameOutput: (widgetSettings.onlySameOutput !== undefined) ? widgetSettings.onlySameOutput : widgetMetadata.onlySameOutput
  readonly property bool onlyActiveWorkspaces: (widgetSettings.onlyActiveWorkspaces !== undefined) ? widgetSettings.onlyActiveWorkspaces : widgetMetadata.onlyActiveWorkspaces
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  readonly property bool showTitle: isVerticalBar ? false : (widgetSettings.showTitle !== undefined) ? widgetSettings.showTitle : (efficientMode ? false : widgetMetadata.showTitle)
  readonly property bool smartWidth: (widgetSettings.smartWidth !== undefined) ? widgetSettings.smartWidth : widgetMetadata.smartWidth
  readonly property int maxTaskbarWidthPercent: (widgetSettings.maxTaskbarWidth !== undefined) ? widgetSettings.maxTaskbarWidth : widgetMetadata.maxTaskbarWidth
  readonly property real iconScale: (widgetSettings.iconScale !== undefined) ? widgetSettings.iconScale : widgetMetadata.iconScale
  readonly property int itemSize: Style.toOdd(capsuleHeight * Math.max(0.1, iconScale))

  // DDE efficient-mode item geometry (DESIGN §3.1.4):
  // item long-axis = barThickness x 1.4, icon = 0.7 x min(width, height)
  readonly property int itemLongLength: efficientMode ? Math.round(barHeight * 1.4) : itemSize
  readonly property int itemIconSize: efficientMode ? Math.round(Math.min(barHeight, itemLongLength) * 0.7) : itemSize

  // Free length the zone can offer this taskbar before items must shrink.
  // Bar.qml feeds it through widgetProps for zones that do not stretch the
  // delegate (the centered zone): reading root.width there is self-referential
  // — the delegate width comes from implicitWidth, which contentWidth derives
  // from this value, so the taskbar could only ever shrink, never grow.
  property real zoneAvailable: -1

  // Proportional shrink when items overflow the available length
  // (gxde-dock mainpanel.cpp:623-698 approach)
  readonly property real availableLength: (zoneAvailable >= 0) ? zoneAvailable : (isVerticalBar ? root.height : root.width)
  readonly property int effectiveItemLongLength: {
    var count = combinedModel.length;
    if (count <= 0 || !efficientMode)
      return itemLongLength;
    var total = count * itemLongLength;
    if (total <= availableLength || availableLength <= 0)
      return itemLongLength;
    return Math.max(1, Math.floor(availableLength / count));
  }

  // Maximum width for the taskbar widget to prevent overlapping with other widgets
  readonly property real maxTaskbarWidth: {
    if (!screen || isVerticalBar || !smartWidth || maxTaskbarWidthPercent <= 0)
      return 0;
    var barFloating = Settings.isBarFloating();
    var barMarginH = barFloating ? Math.ceil(Settings.data.bar.marginHorizontal) : 0;
    var availableWidth = screen.width - (barMarginH * 2);
    return Math.round(availableWidth * (maxTaskbarWidthPercent / 100));
  }

  readonly property int titleWidth: {
    // First, use user-defined title width if set
    var calculatedWidth = (widgetSettings.titleWidth !== undefined) ? widgetSettings.titleWidth : widgetMetadata.titleWidth;

    // Second, shrink title width if it exceeds maxTaskbarWidth when smartWidth is enabled
    if (smartWidth && combinedModel.length > 0) {
      if (maxTaskbarWidth > 0) {
        var entriesCount = combinedModel.length;
        var maxWidthPerEntry = (maxTaskbarWidth / entriesCount) - itemSize - Style.marginS - Style.margin2M;
        calculatedWidth = Math.min(calculatedWidth, maxWidthPerEntry);
      }

      calculatedWidth = Math.max(Math.round(calculatedWidth), 20);
    }

    return calculatedWidth;
  }
  readonly property bool showPinnedApps: (widgetSettings.showPinnedApps !== undefined) ? widgetSettings.showPinnedApps : widgetMetadata.showPinnedApps

  // Context menu state — every window belonging to the right-clicked app so
  // the shared DockMenu can offer grouped actions (DESIGN §3.1.1).
  function windowsForApp(appId) {
    var wins = [];
    for (var i = 0; i < combinedModel.length; i++) {
      var e = combinedModel[i];
      if (e && e.window && e.appId === appId)
        wins.push(e.window);
    }
    return wins;
  }

  // Hover state
  property var hoveredWindowId: ""
  // Combined model of running windows and pinned apps
  property var combinedModel: []
  // Inert entry for delegates that briefly outlive a shrunken combinedModel array
  readonly property var emptyEntry: ({
                                       "id": "",
                                       "type": "",
                                       "window": null,
                                       "appId": "",
                                       "title": ""
                                     })

  // Render model: one row per combinedModel key plus "dying" rows that stay
  // alive while their collapse animation runs (Layouts don't support
  // positioner transitions, so removal is delayed until the row reaches zero
  // long-axis size — the same recipe the fashion dock uses for its app list,
  // DESIGN §1.7 "位移和尺寸 InOutCubic / 退场更快并用 ease-in").
  property ListModel itemRows: ListModel {}
  // rkey -> entry snapshot: combinedModel is rebuilt wholesale on every
  // change, so delegates resolve their data through this map; vanished keys
  // fall back to _limbo while their row collapses.
  property var _entryByKey: ({})
  property var _limbo: ({})

  // Window-object serials: same delayed-removal model needs a STRING key, so
  // stable object identities (Toplevel handles) get synthetic ids. WeakMap so
  // a closed window's object isn't kept alive by its key entry.
  property var _winSerials: new WeakMap()
  property int _serialSeq: 0
  function _serialFor(obj) {
    var s = _winSerials.get(obj);
    if (s === undefined) {
      s = "s" + (++_serialSeq);
      _winSerials.set(obj, s);
    }
    return s;
  }

  // Stable row key: pinned-only apps key by appId (pin/unpin keeps the slot);
  // running entries key per window — niri rows carry `id`, sway rows carry
  // the Toplevel `handle`; either beats appId, which would collapse a
  // multi-window app into one row.
  function _rowKeyFor(entry) {
    if (entry.type === "pinned")
      return "p:" + normalizeAppId(entry.appId);
    var w = entry.window;
    if (w) {
      if (w.id !== undefined)
        return "w:" + w.id;
      if (w.handle)
        return "wh:" + _serialFor(w.handle);
    }
    return "w:" + normalizeAppId(entry.appId);
  }

  function _entryForRow(rkey) {
    var e = _entryByKey[rkey];
    if (e !== undefined)
      return e;
    e = _limbo[rkey];
    return e !== undefined ? e : emptyEntry;
  }

  // combinedModel index of a row key — drag callbacks reason about the live
  // list, not the row index (dying rows hold extra slots). Reads the _rkey
  // stamped in _syncItemRows: recomputing _rowKeyFor here would allocate
  // serials from inside a binding (modelIndex) — a binding loop.
  function _liveIndexOf(rkey) {
    for (var i = 0; i < combinedModel.length; i++) {
      if (combinedModel[i] && combinedModel[i]._rkey === rkey)
        return i;
    }
    return -1;
  }

  function _rowIndexOf(rkey) {
    for (var i = 0; i < itemRows.count; i++) {
      if (itemRows.get(i).rkey === rkey)
        return i;
    }
    return -1;
  }

  // Row index of the n-th non-dying row (-1 when there are fewer).
  function _liveRowPos(n) {
    var seen = 0;
    for (var i = 0; i < itemRows.count; i++) {
      if (!itemRows.get(i).dying) {
        if (seen === n)
          return i;
        seen++;
      }
    }
    return -1;
  }

  // Diff itemRows against combinedModel: survivors keep their delegates so
  // Behaviors animate size/color changes, vanished keys flip to dying and
  // collapse in place, newcomers grow in at their live-order slot.
  function _syncItemRows() {
    var i, k;
    var live = {};
    var oldByKey = _entryByKey;
    var newByKey = {};
    for (i = 0; i < combinedModel.length; i++) {
      var e = combinedModel[i];
      if (!e)
        continue;
      k = _rowKeyFor(e);
      e._rkey = k;
      newByKey[k] = e;
      live[k] = true;
    }
    var limbo = {};
    for (i = 0; i < itemRows.count; i++) {
      var rk = itemRows.get(i).rkey;
      if (!live[rk]) {
        var stale = oldByKey[rk] !== undefined ? oldByKey[rk] : _limbo[rk];
        if (stale !== undefined)
          limbo[rk] = stale;
      }
    }
    _entryByKey = newByKey;
    _limbo = limbo;
    for (i = 0; i < itemRows.count; i++)
      itemRows.setProperty(i, "dying", !live[itemRows.get(i).rkey]);
    var livePos = 0;
    for (i = 0; i < combinedModel.length; i++) {
      var e2 = combinedModel[i];
      if (!e2)
        continue;
      var key = _rowKeyFor(e2);
      var idx = _rowIndexOf(key);
      if (idx < 0) {
        var at = _liveRowPos(livePos);
        itemRows.insert(at === -1 ? itemRows.count : at, {
                          "rkey": key,
                          "dying": false
                        });
      } else {
        var cur = _liveRowPos(livePos);
        if (cur !== -1 && cur !== idx)
          itemRows.move(idx, cur, 1);
      }
      livePos++;
    }
  }

  // Called by a dying delegate once its long axis reached zero.
  function _dropRow(rkey) {
    for (var i = 0; i < itemRows.count; i++) {
      if (itemRows.get(i).rkey === rkey && itemRows.get(i).dying) {
        itemRows.remove(i);
        var l = _limbo;
        delete l[rkey];
        _limbo = l;
        return;
      }
    }
  }

  // Wheel scroll handling
  property int wheelAccumulatedDelta: 0
  property bool wheelCooldown: false

  // Drag and Drop state for visual feedback
  property int dragSourceIndex: -1
  property int dragTargetIndex: -1

  // Track the session order of apps (transient reordering)
  property var sessionAppOrder: []

  function getAppKey(appData) {
    if (!appData)
      return null;
    // prefer window object identity for running apps to distinguish instances
    if (appData.window)
      return appData.window;
    // fallback to appId for pinned-only apps
    return appData.appId;
  }

  function sortApps(apps) {
    if (!sessionAppOrder || sessionAppOrder.length === 0) {
      return apps;
    }

    const sorted = [];
    const remaining = [...apps];

    // 1. Pick apps that are in the session order
    for (let i = 0; i < sessionAppOrder.length; i++) {
      const key = sessionAppOrder[i];
      const idx = remaining.findIndex(app => getAppKey(app) === key);
      if (idx !== -1) {
        sorted.push(remaining[idx]);
        remaining.splice(idx, 1);
      }
    }

    // 2. Append any new/remaining apps
    remaining.forEach(app => sorted.push(app));

    return sorted;
  }

  function reorderApps(fromIndex, toIndex) {
    Logger.d("Taskbar", "Reordering apps from " + fromIndex + " to " + toIndex);
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= combinedModel.length || toIndex >= combinedModel.length)
      return;

    const list = [...combinedModel];
    const item = list.splice(fromIndex, 1)[0];
    list.splice(toIndex, 0, item);

    combinedModel = list;
    _syncItemRows();
    sessionAppOrder = combinedModel.map(getAppKey);
    savePinnedOrder();
  }

  function savePinnedOrder() {
    const currentPinned = Settings.data.dock.pinnedApps || [];
    const newPinned = [];
    const seen = new Set();

    // Extract pinned apps in their current visual order
    combinedModel.forEach(app => {
                            if (app.appId && !seen.has(app.appId)) {
                              const isPinned = currentPinned.some(p => normalizeAppId(p) === normalizeAppId(app.appId));

                              if (isPinned) {
                                newPinned.push(app.appId);
                                seen.add(app.appId);
                              }
                            }
                          });

    // Check if any pinned apps were missed (e.g. filtered out by workspace)
    currentPinned.forEach(p => {
                            if (!seen.has(p)) {
                              newPinned.push(p);
                              seen.add(p);
                            }
                          });

    if (JSON.stringify(currentPinned) !== JSON.stringify(newPinned)) {
      Settings.data.dock.pinnedApps = newPinned;
    }
  }

  // Helper functions forwarded to the shared AppIdMatcher singleton; the
  // taskbar keeps raw app IDs (no ".desktop" suffix stripping), matches pins
  // via desktop entry resolution (strong match) and pins desktop entry IDs.
  function normalizeAppId(appId) {
    return AppIdMatcher.normalizeAppId(appId);
  }

  function isAppIdPinned(appId, pinnedApps) {
    return AppIdMatcher.isAppIdPinned(appId, pinnedApps, {
                                        resolveEntry: true
                                      });
  }

  function resolveToDesktopEntryId(appId) {
    return AppIdMatcher.resolveToDesktopEntryId(appId);
  }

  function getAppNameFromDesktopEntry(appId) {
    return AppIdMatcher.getAppNameFromDesktopEntry(appId);
  }

  function getDesktopEntryId(appId) {
    return AppIdMatcher.getDesktopEntryId(appId);
  }

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

  // Function to update the combined model
  function updateCombinedModel() {
    const runningWindows = [];
    const pinnedApps = Settings.data.dock.pinnedApps || [];
    const processedAppIds = new Set();

    // First pass: Add all running windows
    try {
      const total = CompositorService.windows.count || 0;
      const activeIds = CompositorService.getActiveWorkspaces().map(function (ws) {
        return ws.id;
      });

      for (var i = 0; i < total; i++) {
        var w = CompositorService.windows.get(i);
        if (!w)
          continue;
        // Unknown output/workspace passes the gate: backends that don't report
        // them must not empty the taskbar (hermes-03: enumerate failures made
        // hideMode:"hidden" drop the whole strip).
        var passOutput = (!onlySameOutput) || (!w.output) || (w.output === screen?.name);
        var passWorkspace = (!onlyActiveWorkspaces) || (w.workspaceId === undefined || w.workspaceId < 0) || (activeIds.includes(w.workspaceId));
        if (passOutput && passWorkspace) {
          const isPinned = isAppIdPinned(w.appId, pinnedApps);
          runningWindows.push({
                                "id": w.id,
                                "type": isPinned ? "pinned-running" : "running",
                                "window": w,
                                "appId": w.appId,
                                "title": w.title || getAppNameFromDesktopEntry(w.appId)
                              });
          processedAppIds.add(normalizeAppId(w.appId));
          // Also track the resolved desktop entry ID so pinned app matching works
          const resolvedId = resolveToDesktopEntryId(w.appId);
          if (resolvedId !== w.appId)
            processedAppIds.add(normalizeAppId(resolvedId));
        }
      }
    } catch (e)
      // Ignore errors
    {}

    // Second pass: Add non-running pinned apps (only if showPinnedApps is enabled)
    if (showPinnedApps) {
      pinnedApps.forEach(pinnedAppId => {
                           const normalizedPinnedId = normalizeAppId(pinnedAppId);
                           if (!processedAppIds.has(normalizedPinnedId)) {
                             const appName = getAppNameFromDesktopEntry(pinnedAppId);
                             runningWindows.push({
                                                   "id": pinnedAppId,
                                                   "type": "pinned",
                                                   "window": null,
                                                   "appId": pinnedAppId,
                                                   "title": appName
                                                 });
                           }
                         });
    }

    combinedModel = sortApps(runningWindows);
    _syncItemRows();

    // Sync session order if needed (e.g. first run or new apps added)
    if (!sessionAppOrder || sessionAppOrder.length === 0 || sessionAppOrder.length !== combinedModel.length) {
      sessionAppOrder = combinedModel.map(getAppKey);
    }
    updateHasWindow();
  }

  // Function to launch a pinned app
  function launchPinnedApp(appId) {
    if (!appId)
      return;

    try {
      const app = DesktopEntries.byId(appId);
      CompositorService.launchDesktopEntry(app);
    } catch (e) {
      Logger.e("Taskbar", "Failed to launch app: " + e);
    }
  }

  // App-item context menu: the same dark arrowed menu the fashion dock uses
  // (DESIGN §3.1.1). Entries are CompositorService backend windows, not
  // Toplevels — backendWindows routes focus/close through the service.
  DockMenu {
    id: appMenu
    dockPosition: root.barPosition
    backendWindows: true
  }

  function updateHasWindow() {
    // Check if we have any items in the combined model (windows or pinned apps)
    hasWindow = combinedModel.length > 0;
  }

  Connections {
    target: CompositorService
    function onActiveWindowChanged() {
      updateCombinedModel();
    }
    function onWindowListChanged() {
      updateCombinedModel();
    }
    function onWorkspaceChanged() {
      updateCombinedModel();
    }
  }

  Connections {
    target: Settings.data.dock
    function onPinnedAppsChanged() {
      updateCombinedModel();
    }
  }

  Component.onCompleted: {
    updateCombinedModel();
  }
  onScreenChanged: updateCombinedModel()

  // Debounce timer for wheel interactions
  Timer {
    id: wheelDebounce
    interval: 150
    repeat: false
    onTriggered: {
      root.wheelCooldown = false;
      root.wheelAccumulatedDelta = 0;
    }
  }

  // Scroll to switch between windows
  WheelHandler {
    id: wheelHandler
    target: root
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function (event) {
      if (root.wheelCooldown || root.combinedModel.length === 0)
        return;
      var dy = event.angleDelta.y;
      var dx = event.angleDelta.x;
      var useDy = Math.abs(dy) >= Math.abs(dx);
      var delta = useDy ? dy : dx;
      root.wheelAccumulatedDelta += delta;
      var step = 120;
      if (Math.abs(root.wheelAccumulatedDelta) >= step) {
        var direction = root.wheelAccumulatedDelta > 0 ? -1 : 1;
        // Find the focused window or first running window
        var currentIndex = -1;
        for (var i = 0; i < root.combinedModel.length; i++) {
          if (root.combinedModel[i].window && root.combinedModel[i].window.isFocused) {
            currentIndex = i;
            break;
          }
        }
        if (currentIndex < 0) {
          // No focused window, find first running window
          for (var j = 0; j < root.combinedModel.length; j++) {
            if (root.combinedModel[j].window) {
              currentIndex = j;
              break;
            }
          }
        }
        if (currentIndex >= 0) {
          var nextIndex = (currentIndex + direction + root.combinedModel.length) % root.combinedModel.length;
          var nextItem = root.combinedModel[nextIndex];
          if (nextItem && nextItem.window) {
            try {
              CompositorService.focusWindow(nextItem.window);
            } catch (error) {
              Logger.e("Taskbar", "Failed to focus window: " + error);
            }
          }
        }
        root.wheelCooldown = true;
        wheelDebounce.restart();
        root.wheelAccumulatedDelta = 0;
        event.accepted = true;
      }
    }
  }

  // "visible": Always Visible, "hidden": Hide When Empty, "transparent": Transparent When Empty
  visible: hideMode !== "hidden" || hasWindow
  opacity: ((hideMode !== "hidden" && hideMode !== "transparent") || hasWindow) ? 1.0 : 0.0
  Behavior on opacity {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  // Content dimensions for implicit sizing
  readonly property real contentWidth: {
    if (!visible)
      return 0;
    if (efficientMode)
      return isVerticalBar ? barHeight : Math.max(itemLongLength, combinedModel.length * effectiveItemLongLength);
    if (isVerticalBar)
      return barHeight;

    var calculatedWidth = showTitle ? taskbarLayout.implicitWidth : taskbarLayout.implicitWidth + Style.margin2M;

    // Apply maximum width constraint when smartWidth is enabled
    if (smartWidth && maxTaskbarWidth > 0) {
      return Math.min(calculatedWidth, maxTaskbarWidth);
    }

    return Math.round(calculatedWidth);
  }
  readonly property real contentHeight: {
    if (!visible)
      return 0;
    if (efficientMode)
      return isVerticalBar ? Math.max(itemLongLength, combinedModel.length * effectiveItemLongLength) : barHeight;
    return isVerticalBar ? Math.round(taskbarLayout.implicitHeight + Style.margin2S) : capsuleHeight;
  }

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Right-click on empty taskbar space (the stretched remainder in efficient
  // mode, or padding around the capsule otherwise) opens the DDE light dock
  // settings menu — the bar-level handler skips points it considers over a
  // widget, so the widget itself must claim them.
  MouseArea {
    z: -1
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onClicked: mouse => {
                 TooltipService.hideImmediately();
                 DockSettingsMenu.openAtItemPoint(screen, this, mouse.x, mouse.y);
               }
  }

  // Visual capsule centered in parent (efficient mode packs items from the
  // start edge — Win10/DDE taskbar style — instead of centering them)
  Rectangle {
    id: visualCapsule
    width: root.contentWidth
    height: root.contentHeight
    x: (root.efficientMode && !isVerticalBar) ? 0 : Style.pixelAlignCenter(parent.width, width)
    y: (root.efficientMode && isVerticalBar) ? 0 : Style.pixelAlignCenter(parent.height, height)
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    GridLayout {
      id: taskbarLayout

      // Pixel-perfect centering (efficient mode packs items from the start edge)
      x: isVerticalBar ? Style.pixelAlignCenter(parent.width, width) : (root.efficientMode ? 0 : ((root.showTitle) ? Style.pixelAlignCenter(parent.width, width) : Style.marginM))
      y: (isVerticalBar && root.efficientMode) ? 0 : Style.pixelAlignCenter(parent.height, height)

      // Configure GridLayout to behave like RowLayout or ColumnLayout
      rows: isVerticalBar ? -1 : 1 // -1 means unlimited
      columns: isVerticalBar ? 1 : -1 // -1 means unlimited

      rowSpacing: isVerticalBar ? Style.marginXXS : 0
      columnSpacing: isVerticalBar ? 0 : Style.marginXXS

      // Model is the keyed row list (root.itemRows): delegates survive data
      // rebuilds so add/remove changes animate, and dying rows collapse in
      // place before _dropRow removes them.
      Repeater {
        model: root.itemRows
        delegate: Item {
          id: taskbarItem
          required property int index
          readonly property var modelData: root._entryForRow(model.rkey)
          // Hover/drag identity is the row key — sway window rows carry no
          // `id` field, so entry.id collapses every window to undefined.
          readonly property string rowKey: model.rkey || ""
          property ShellScreen screen: root.screen

          readonly property bool isRunning: modelData.window !== null
          readonly property bool isPinned: modelData.type === "pinned" || modelData.type === "pinned-running"
          readonly property bool isFocused: isRunning && modelData.window && modelData.window.isFocused
          readonly property bool isPinnedRunning: isPinned && isRunning && !isFocused
          readonly property bool isHovered: root.hoveredWindowId === taskbarItem.rowKey
          readonly property bool isUrgent: isRunning && modelData.window && modelData.window.isUrgent === true

          readonly property bool shouldShowTitle: root.showTitle && modelData.type !== "pinned"
          readonly property real itemSpacing: Style.marginS
          readonly property real contentWidth: shouldShowTitle ? root.itemSize + itemSpacing + root.titleWidth : root.itemSize

          readonly property string title: modelData.title || modelData.appId || "Unknown application"
          readonly property color titleBgColor: (isHovered || isFocused) ? Color.mHover : Style.capsuleColor
          readonly property color titleFgColor: (isHovered || isFocused) ? Color.mOnHover : Color.mOnSurface

          // Collapse/grow lifecycle: rows enter at 0 and dying rows collapse
          // back to 0 on the long axis before the model drops them.
          readonly property bool collapsing: model.dying === true
          property bool _entered: false
          Component.onCompleted: _entered = true
          readonly property bool _shrunk: collapsing || !_entered
          readonly property real longLen_: root.isVerticalBar ? Layout.preferredHeight : Layout.preferredWidth
          onLongLen_Changed: {
            if (collapsing && longLen_ <= 0)
              root._dropRow(model.rkey);
          }

          opacity: _shrunk ? 0 : 1
          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }

          Layout.preferredWidth: root.efficientMode ? (root.isVerticalBar ? root.barHeight : (taskbarItem._shrunk ? 0 : root.effectiveItemLongLength)) : (root.isVerticalBar ? root.barHeight : (taskbarItem._shrunk ? 0 : (root.showTitle ? Math.round(contentWidth + Style.margin2M) : Math.round(contentWidth)))) // Add margins for both pinned and running apps
          Layout.preferredHeight: root.efficientMode ? (root.isVerticalBar ? (taskbarItem._shrunk ? 0 : root.effectiveItemLongLength) : root.barHeight) : (root.isVerticalBar ? (taskbarItem._shrunk ? 0 : root.itemSize) : root.barHeight)
          Layout.alignment: Qt.AlignCenter

          Behavior on Layout.preferredWidth {
            NumberAnimation {
              duration: taskbarItem.collapsing ? Style.animationFast : Style.animationNormal
              easing.type: taskbarItem.collapsing ? Easing.InCubic : Easing.InOutCubic
            }
          }
          Behavior on Layout.preferredHeight {
            NumberAnimation {
              duration: taskbarItem.collapsing ? Style.animationFast : Style.animationNormal
              easing.type: taskbarItem.collapsing ? Easing.InCubic : Easing.InOutCubic
            }
          }

          // Ensure dragged item is on top
          z: (root.dragSourceIndex === modelIndex) ? 1000 : 1

          property int modelIndex: root._liveIndexOf(model.rkey)
          objectName: "taskbarAppItem"

          // DDE efficient-mode state fill on the item rect inset by 1 px
          // (DESIGN §3.1.4): active accent@0.3, attention@0.8, running overlay("strong")
          Rectangle {
            visible: root.efficientMode
            anchors.fill: parent
            anchors.margins: 1
            color: {
              if (taskbarItem.isFocused)
                return Qt.alpha(Color.accent, 0.3);
              if (taskbarItem.isUrgent)
                return Qt.alpha(Color.attention, 0.8);
              if (taskbarItem.isRunning)
                return Color.overlay("strong");
              return "transparent";
            }
          }

          // Accent edge line on the screen-edge side for the active window
          // (4 px when the item thickness is > 50, otherwise 2 px)
          Rectangle {
            visible: root.efficientMode && taskbarItem.isFocused
            color: Color.accent
            readonly property real lw: root.barHeight > 50 ? 4 : 2
            x: root.barPosition === "left" ? 0 : (root.barPosition === "right" ? parent.width - width : 0)
            y: root.barPosition === "top" ? 0 : (root.barPosition === "bottom" ? parent.height - height : 0)
            width: root.isVerticalBar ? lw : parent.width
            height: root.isVerticalBar ? parent.height : lw
          }

          DropArea {
            anchors.fill: parent
            keys: ["taskbar-app"]
            onEntered: function (drag) {
              if (drag.source && drag.source.objectName === "taskbarAppItem") {
                root.dragTargetIndex = taskbarItem.modelIndex;
              }
            }
            onExited: function () {
              if (root.dragTargetIndex === taskbarItem.modelIndex) {
                root.dragTargetIndex = -1;
              }
            }
            onDropped: function (drop) {
              root.dragSourceIndex = -1;
              root.dragTargetIndex = -1;
              Logger.d("Taskbar", "Dropped! Source: " + (drop.source ? drop.source.objectName : "null") + " Index: " + (drop.source ? drop.source.modelIndex : "?") + " -> Target Index: " + taskbarItem.modelIndex);
              if (drop.source && drop.source.objectName === "taskbarAppItem" && drop.source !== taskbarItem) {
                root.reorderApps(drop.source.modelIndex, taskbarItem.modelIndex);
              } else {
                Logger.d("Taskbar", "Drop ignored. Source objectName: " + (drop.source ? drop.source.objectName : "null"));
              }
            }
          }

          Item {
            id: draggableContent
            width: parent.width
            height: parent.height
            anchors.centerIn: dragging ? undefined : parent

            // Visual shifting logic
            readonly property bool isDragged: root.dragSourceIndex === taskbarItem.modelIndex
            property real shiftOffset: 0

            // Calculate shift based on drag state
            // If I am NOT the dragged item, but I am in the path of the drag
            // (modelIndex = position in the live list; dying rows don't count)
            Binding on shiftOffset {
              value: {
                if (root.dragSourceIndex !== -1 && root.dragTargetIndex !== -1 && !draggableContent.isDragged) {
                  if (root.dragSourceIndex < root.dragTargetIndex) {
                    // Dragging Right: Items between source and target shift Left
                    if (taskbarItem.modelIndex > root.dragSourceIndex && taskbarItem.modelIndex <= root.dragTargetIndex) {
                      return -1 * (root.isVerticalBar ? root.itemSize : draggableContent.width); // Simple approximation, could be refined
                    }
                  } else if (root.dragSourceIndex > root.dragTargetIndex) {
                    // Dragging Left: Items between target and source shift Right
                    if (taskbarItem.modelIndex >= root.dragTargetIndex && taskbarItem.modelIndex < root.dragSourceIndex) {
                      return (root.isVerticalBar ? root.itemSize : draggableContent.width);
                    }
                  }
                }
                return 0;
              }
            }

            transform: Translate {
              x: !root.isVerticalBar ? draggableContent.shiftOffset : 0
              y: root.isVerticalBar ? draggableContent.shiftOffset : 0

              Behavior on x {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.InOutCubic
                }
              }
              Behavior on y {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.InOutCubic
                }
              }
            }

            property bool dragging: taskbarMouseArea.drag.active
            onDraggingChanged: {
              if (dragging) {
                root.dragSourceIndex = taskbarItem.modelIndex;
              } else {
                // Don't reset synchronously here: the drop handler fires on
                // release and resets on success. If the release lands on no
                // drop target at all, the deferred check clears the drag
                // state once drag.active is observably false.
                if (root.dragSourceIndex === taskbarItem.modelIndex) {
                  Qt.callLater(() => {
                                 if (!taskbarMouseArea.drag.active && root.dragSourceIndex === taskbarItem.modelIndex) {
                                   root.dragSourceIndex = -1;
                                   root.dragTargetIndex = -1;
                                 }
                               });
                }
              }
            }

            Drag.active: dragging
            Drag.source: taskbarItem
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.keys: ["taskbar-app"]

            z: dragging ? 1000 : 0
            scale: dragging ? 1.05 : 1.0
            Behavior on scale {
              NumberAnimation {
                duration: Style.animationFast
              }
            }

            Rectangle {
              id: titleBackground
              visible: shouldShowTitle
              anchors.centerIn: parent
              width: parent.width
              height: root.capsuleHeight
              color: titleBgColor
              radius: Style.radiusM
            }

            Rectangle {
              anchors.centerIn: parent
              width: taskbarItem.contentWidth
              height: parent.height
              color: "transparent"

              RowLayout {
                id: itemLayout
                anchors.fill: parent
                spacing: taskbarItem.itemSpacing

                Item {
                  Layout.preferredWidth: root.efficientMode ? root.itemIconSize : root.itemSize
                  Layout.preferredHeight: root.efficientMode ? root.itemIconSize : root.itemSize
                  Layout.alignment: Qt.AlignCenter

                  // DDE: hovering a taskbar item brightens the icon, no extra background.
                  // layer.enabled must never toggle from hover-driven bindings: Qt
                  // reparents the layer's effectSource/effect into our parent item and
                  // deletes them synchronously on disable — a use-after-free for any
                  // in-flight hover delivery snapshot.
                  layer.enabled: root.efficientMode
                  layer.effect: MultiEffect {
                    brightness: taskbarItem.isHovered ? 0.15 : 0.0
                  }

                  IconImage {
                    id: appIcon
                    anchors.fill: parent

                    source: ThemeIcons.iconForAppId(taskbarItem.modelData.appId)
                    smooth: true
                    asynchronous: true

                    // Dim pinned apps that aren't running (dock.deadOpacity;
                    // DockContent.qml applies the same rule in fashion mode)
                    opacity: taskbarItem.isRunning ? 1.0 : (Settings.data.dock.deadOpacity)

                    Behavior on opacity {
                      NumberAnimation {
                        duration: Style.animationFast
                        easing.type: Easing.OutCubic
                      }
                    }

                    // Apply dock shader to all taskbar icons
                    layer.enabled: root.colorizeIcons
                    layer.effect: ShaderEffect {
                      property color targetColor: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mSurfaceVariant
                      property real colorizeMode: 0.0 // Dock mode (grayscale)

                      fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
                    }
                  }

                  Rectangle {
                    id: iconBackground
                    visible: !shouldShowTitle && !root.efficientMode
                    anchors.bottomMargin: -2
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Style.toOdd(root.itemSize * 0.25)
                    height: 4
                    color: taskbarItem.isFocused ? Color.mPrimary : (taskbarItem.isHovered ? Color.mHover : "transparent")
                    radius: Math.min(Style.radiusXXS, width / 2)
                  }
                }

                NText {
                  id: titleText
                  visible: shouldShowTitle
                  Layout.preferredWidth: root.titleWidth
                  Layout.preferredHeight: root.itemSize
                  Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                  Layout.fillWidth: false

                  text: taskbarItem.title
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignLeft

                  pointSize: barFontSize
                  color: titleFgColor
                  opacity: Style.opacityFull
                }
              }
            }
          }

          MouseArea {
            id: taskbarMouseArea
            objectName: "taskbarMouseArea"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            drag.target: draggableContent
            drag.axis: root.isVerticalBar ? Drag.YAxis : Drag.XAxis
            preventStealing: true

            // The icon square is centred; the dark window menu is only
            // reachable inside it (DESIGN §3.1.1 right-click zones).
            // With a title shown the title block belongs to the same item
            // and keeps the dark menu too.
            function insideItemContent(mx, my) {
              if (shouldShowTitle && mx >= 0 && mx <= width && my >= 0 && my <= height) {
                return true;
              }
              var s = root.efficientMode ? root.itemIconSize : root.itemSize;
              var cx = (width - s) / 2;
              var cy = (height - s) / 2;
              return mx >= cx && mx <= cx + s && my >= cy && my <= cy + s;
            }

            // Constrain drag to roughly the taskbar area but allow some freedom
            // Or just let it be free since we only care about drops
            onPressed: {}

            onReleased: {
              if (draggableContent.Drag.active) {
                draggableContent.Drag.drop();
              }
            }

            onClicked: mouse => {
                         if (!modelData)
                         return;
                         if (mouse.button === Qt.LeftButton) {
                           if (isRunning && modelData.window) {
                             // Running app - focus it
                             try {
                               CompositorService.focusWindow(modelData.window);
                             } catch (error) {
                               Logger.e("Taskbar", "Failed to activate toplevel: " + error);
                             }
                           } else if (isPinned) {
                             // Pinned app not running - launch it
                             root.launchPinnedApp(modelData.appId);
                           }
                         } else if (mouse.button === Qt.RightButton) {
                           TooltipService.hideImmediately();
                           // The icon square gets the dark app menu — running
                           // or pinned alike (a pinned app that is not running
                           // still offers open/unpin, DDE/Windows style).
                           // Outside the icon square -> light settings menu.
                           if (modelData && insideItemContent(mouse.x, mouse.y) && (modelData.appId || modelData.window)) {
                             appMenu.show(taskbarItem, {
                                            "appId": modelData.appId,
                                            "toplevels": root.windowsForApp(modelData.appId)
                                          }, root.screen);
                             return;
                           }
                           DockSettingsMenu.openAtItemPoint(screen, taskbarMouseArea, mouse.x, mouse.y);
                         }
                       }
            onEntered: {
              root.hoveredWindowId = taskbarItem.rowKey;
              TooltipService.show(taskbarItem, taskbarItem.title, BarService.getTooltipDirection(root.screen?.name, root.section === "dock"));
            }
            onExited: {
              root.hoveredWindowId = "";
              TooltipService.hide();
            }
          }
        }
      }
    }
  }
}
