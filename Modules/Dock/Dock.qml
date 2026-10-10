import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// DDE 15 fashion-mode dock (DESIGN §3.1.1, §3.1.2):
// centered floating dock flush against the screen edge, maskShell rounded
// surface, DDE item geometry (thickness = iconSize*1.5, length = thickness*1.1,
// icon = 0.8*min), max length = edge - 60, 2 px sliver when hidden.
// The legacy attached-dock path (dockType/sitOnFrame/backgroundOpacity/size/
// displayMode/floatingRatio keys, StaticDockPanel) was removed — nothing ever
// opened that panel.
Loader {

  active: Settings.data.dock.enabled && Settings.data.dock.mode === "fashion"
  sourceComponent: Variants {
    model: Quickshell.screens

    delegate: Item {
      id: root

      required property ShellScreen modelData

      // The injected modelData can hold a ShellScreen the compositor
      // replaced after this delegate was created (its name survives but
      // width/height freeze at a transient value). All geometry must go
      // through the live object — see PanelService.liveScreen.
      readonly property ShellScreen liveScreen: PanelService.liveScreen(modelData)

      // ------------------------------------------------------------------
      // DDE fashion geometry (gxde-dock mainpanel / dockitem sizing)
      // ------------------------------------------------------------------
      readonly property string dockPosition: Settings.getTaskbarPositionForScreen(liveScreen?.name)
      readonly property bool isVertical: dockPosition === "left" || dockPosition === "right"
      readonly property int iconSize: Settings.data.dock.iconSize // 30/36/48 presets
      readonly property int itemThickness: Style.dockItemThickness
      readonly property int itemLength: Style.dockItemLength
      readonly property int iconContent: Style.dockIconContent
      // Fashion dock is centered and capped to the screen edge minus 30 px on
      // each side (gxde-dock DockPanel::m_itemManager margins)
      readonly property int maxLength: Math.max(0, (isVertical ? (liveScreen?.height ?? 0) : (liveScreen?.width ?? 0)) - 60)

      // ------------------------------------------------------------------
      // Hide behaviour: keep-showing reserves space; keep-hidden leaves a
      // 2 px sliver on the docked edge; smart-hide falls back to keep-hidden
      // (same fallback as efficient mode — no window-overlap info available).
      // ------------------------------------------------------------------
      readonly property string hideMode: Settings.data.dock.hideMode
      readonly property bool autoHide: hideMode !== "keep-showing"
      readonly property int hiddenSliver: 2
      readonly property int showDelay: 100
      readonly property int hideDelay: 100
      property bool hidden: autoHide

      // A fullscreen window on this output covers the dock regardless of
      // hideMode (DDE keeps the dock hidden under fullscreen apps): slides
      // fully off the edge with no hover sliver.
      readonly property bool fullscreenCovered: liveScreen ? CompositorService.outputHasFullscreen(liveScreen.name) : false

      property bool _smartHideWarned: false
      Component.onCompleted: {
        if (ToplevelManager)
          updateDockApps();
        if (hideMode === "smart-hide" && !_smartHideWarned) {
          _smartHideWarned = true;
          Logger.i("Dock", "smart-hide is not supported on this compositor; falling back to keep-hidden behaviour");
        }
      }
      onHideModeChanged: {
        if (hideMode === "smart-hide" && !_smartHideWarned) {
          _smartHideWarned = true;
          Logger.i("Dock", "smart-hide is not supported on this compositor; falling back to keep-hidden behaviour");
        }
      }

      // Shared state between window and content
      property bool dockHovered: false
      property bool anyAppHovered: false
      property bool menuHovered: false
      property var currentContextMenu: null

      // Combined model of running apps and pinned apps
      property var dockApps: []
      property var groupCycleIndices: ({})
      property var sessionAppOrder: []

      // Drag and Drop state for visual feedback
      property int dragSourceIndex: -1
      property int dragTargetIndex: -1

      // Revision counter to force icon re-evaluation
      property int iconRevision: 0

      // Update dock apps when window list change
      Connections {
        target: CompositorService
        function onWindowListChanged() {
          updateDockApps();
        }
      }

      // Update dock apps when toplevels change
      Connections {
        target: ToplevelManager ? ToplevelManager.toplevels : null
        function onValuesChanged() {
          updateDockApps();
        }
      }

      // Update dock apps when pinned apps change
      Connections {
        target: Settings.data.dock
        function onPinnedAppsChanged() {
          updateDockApps();
        }
        function onOnlySameOutputChanged() {
          updateDockApps();
        }
        function onGroupAppsChanged() {
          updateDockApps();
        }
      }

      // Refresh icons and names when DesktopEntries becomes available (or updates)
      Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
          root.iconRevision++;
          updateDockApps();
        }
      }

      // when dragging ended but the cursor is outside the dock area, restart the timer
      onDragSourceIndexChanged: {
        if (dragSourceIndex === -1) {
          if (autoHide && !dockHovered && !anyAppHovered && !menuHovered) {
            hideTimer.restart();
          }
        }
      }

      function closeAllContextMenus() {
        if (currentContextMenu && currentContextMenu.visible) {
          currentContextMenu.hide();
        }
      }

      function getAppKey(appData) {
        if (!appData)
          return null;

        if (Settings.data.dock.groupApps) {
          return appData.appId;
        }

        // Use stable appId for pinned apps to maintain their slot regardless of running state
        if (appData.type === "pinned" || appData.type === "pinned-running") {
          return appData.appId;
        }

        // prefer toplevel object identity for unpinned running apps to distinguish instances
        if (appData.toplevel)
          return appData.toplevel;

        // fallback to appId
        return appData.appId;
      }

      function sortDockApps(apps) {
        if (!sessionAppOrder || sessionAppOrder.length === 0) {
          return apps;
        }

        const sorted = [];
        const remaining = [...apps];

        // Pick apps that are in the session order
        for (let i = 0; i < sessionAppOrder.length; i++) {
          const key = sessionAppOrder[i];

          // Pick ALL matching apps (e.g. all instances of a pinned app)
          while (true) {
            const idx = remaining.findIndex(app => getAppKey(app) === key);
            if (idx !== -1) {
              sorted.push(remaining[idx]);
              remaining.splice(idx, 1);
            } else {
              break;
            }
          }
        }

        // Append any new/remaining apps
        remaining.forEach(app => sorted.push(app));

        return sorted;
      }

      function reorderApps(fromIndex, toIndex) {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= dockApps.length || toIndex >= dockApps.length)
          return;

        const list = [...dockApps];
        const item = list.splice(fromIndex, 1)[0];
        list.splice(toIndex, 0, item);

        dockApps = list;
        sessionAppOrder = dockApps.map(getAppKey);
        savePinnedOrder();
      }

      function savePinnedOrder() {
        const currentPinned = Settings.data.dock.pinnedApps || [];
        const newPinned = [];
        const seen = new Set();

        // Extract pinned apps in their current visual order
        dockApps.forEach(app => {
                           if (app.appId && !seen.has(app.appId)) {
                             const isPinned = currentPinned.some(p => normalizeAppId(p) === normalizeAppId(app.appId));

                             if (isPinned) {
                               newPinned.push(app.appId);
                               seen.add(app.appId);
                             }
                           }
                         });

        // Check if any pinned apps were missed (unlikely if dockApps is correct)
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
      // dock strips the ".desktop" suffix when normalizing pinned keys and
      // matches pins via desktop entry resolution (strong match).
      function normalizeAppId(appId) {
        return AppIdMatcher.normalizeAppId(appId, {
                 stripDesktopSuffix: true
               });
      }

      function isAppIdPinned(appId, pinnedApps) {
        return AppIdMatcher.isAppIdPinned(appId, pinnedApps, {
                 stripDesktopSuffix: true,
                 resolveEntry: true
               });
      }

      function resolveToDesktopEntryId(appId) {
        return AppIdMatcher.resolveToDesktopEntryId(appId);
      }

      function getAppNameFromDesktopEntry(appId) {
        return AppIdMatcher.getAppNameFromDesktopEntry(appId);
      }

      // onlySameOutput predicate against the live ShellScreen — a stale
      // modelData makes identity includes() permanently false.
      function onLiveScreen(screens) {
        if (!Settings.data.dock.onlySameOutput || !screens || !liveScreen)
          return true;
        for (var i = 0; i < screens.length; i++) {
          if (screens[i] === liveScreen || (screens[i] && screens[i].name === liveScreen.name))
            return true;
        }
        return false;
      }

      function getToplevelsForEntry(appData) {
        if (!appData)
          return [];

        if (appData.toplevels && appData.toplevels.length > 0) {
          return appData.toplevels.filter(toplevel => toplevel && onLiveScreen(toplevel.screens));
        }

        if (!appData.toplevel)
          return [];

        if (!onLiveScreen(appData.toplevel.screens))
          return [];

        return [appData.toplevel];
      }

      function getPrimaryToplevelForEntry(appData) {
        const toplevels = getToplevelsForEntry(appData);
        if (toplevels.length === 0)
          return null;

        if (ToplevelManager && ToplevelManager.activeToplevel && toplevels.includes(ToplevelManager.activeToplevel))
          return ToplevelManager.activeToplevel;

        return toplevels[0];
      }

      // Build grouped render model without mutating the raw toplevel list.
      function buildGroupedDockApps(apps) {
        if (!Settings.data.dock.groupApps) {
          return apps.map(app => {
                            const entry = Object.assign({}, app);
                            entry.toplevels = getToplevelsForEntry(app);
                            return entry;
                          });
        }

        const grouped = [];
        const groupedById = new Map();

        apps.forEach(app => {
                       const appId = app.appId;
                       const toplevels = getToplevelsForEntry(app);
                       const existing = groupedById.get(appId);

                       if (existing) {
                         toplevels.forEach(toplevel => {
                                             if (!existing.toplevels.includes(toplevel)) {
                                               existing.toplevels.push(toplevel);
                                             }
                                           });
                         if (app.type === "pinned" || app.type === "pinned-running") {
                           existing.isPinned = true;
                         }
                       } else {
                         const entry = {
                           "type": app.type,
                           "appId": appId,
                           "title": app.title,
                           "toplevels": toplevels.slice(),
                           "isPinned": app.type === "pinned" || app.type === "pinned-running"
                         };
                         grouped.push(entry);
                         groupedById.set(appId, entry);
                       }
                     });

        grouped.forEach(entry => {
                          entry.toplevel = getPrimaryToplevelForEntry(entry);
                          if (entry.toplevels.length > 0 && entry.isPinned) {
                            entry.type = "pinned-running";
                          } else if (entry.toplevels.length > 0) {
                            entry.type = "running";
                          } else {
                            entry.type = "pinned";
                          }
                          if (entry.toplevel && entry.toplevel.title && entry.toplevel.title.trim() !== "") {
                            entry.title = entry.toplevel.title;
                          }
                        });

        return grouped;
      }

      // Identity comparison: same app order, type, pin state and toplevel
      // objects → the delegates' live bindings (title, urgent, active)
      // already reflect the change; reassigning the array would only force
      // a full delegate teardown/re-incubation for no visual gain.
      function _sameDockApps(a, b) {
        if (a.length !== b.length)
          return false;
        for (var i = 0; i < a.length; i++) {
          const x = a[i], y = b[i];
          if (x.appId !== y.appId || x.type !== y.type || x.isPinned !== y.isPinned)
            return false;
          const ta = x.toplevels || [], tb = y.toplevels || [];
          if (ta.length !== tb.length)
            return false;
          for (var j = 0; j < ta.length; j++) {
            if (ta[j] !== tb[j])
              return false;
          }
        }
        return true;
      }

      // Coalesce dockApps rebuilds: callers fire on every toplevel/window/pin
      // change, and rebuilding synchronously inside those signal handlers
      // re-enters the Repeater's delegate incubation (QQmlIncubator UAF — the
      // crash class NotificationService and the launcher model already guard
      // against). Queue one rebuild per event-loop turn instead.
      property bool _dockAppsUpdateQueued: false
      function updateDockApps() {
        if (_dockAppsUpdateQueued)
          return;
        _dockAppsUpdateQueued = true;
        Qt.callLater(_updateDockAppsNow);
      }

      function _updateDockAppsNow() {
        _dockAppsUpdateQueued = false;
        const runningApps = ToplevelManager ? (ToplevelManager.toplevels.values || []) : [];
        const pinnedApps = Settings.data.dock.pinnedApps || [];
        const combined = [];
        const processedToplevels = new Set();
        const processedPinnedAppIds = new Set();

        //push an app onto combined with the given appType
        function pushApp(appType, toplevel, appId, title) {
          // Use canonical ID for pinned apps to ensure key stability
          const canonicalId = isAppIdPinned(appId, pinnedApps) ? (pinnedApps.find(p => normalizeAppId(p) === normalizeAppId(appId)) || appId) : appId;

          // For running apps, track by toplevel object to allow multiple instances
          if (toplevel) {
            if (processedToplevels.has(toplevel)) {
              return; // Already processed this toplevel instance
            }
            if (!onLiveScreen(toplevel.screens)) {
              return; // Filtered out by onlySameOutput setting
            }
            combined.push({
                            "type": appType,
                            "toplevel": toplevel,
                            "toplevels": toplevel ? [toplevel] : [],
                            "appId": canonicalId,
                            "title": title
                          });
            processedToplevels.add(toplevel);
          } else {
            // For pinned apps that aren't running, track by appId to avoid duplicates
            if (processedPinnedAppIds.has(canonicalId)) {
              return; // Already processed this pinned app
            }
            combined.push({
                            "type": appType,
                            "toplevel": toplevel,
                            "toplevels": [],
                            "appId": canonicalId,
                            "title": title
                          });
            processedPinnedAppIds.add(canonicalId);
          }
        }

        function pushRunning(first) {
          runningApps.forEach(toplevel => {
                                if (toplevel) {
                                  // Use robust matching to check if pinned
                                  const isPinned = isAppIdPinned(toplevel.appId, pinnedApps);
                                  if (!first && isPinned && processedToplevels.has(toplevel)) {
                                    return; // Already added by pushPinned()
                                  }
                                  pushApp((first && isPinned) ? "pinned-running" : "running", toplevel, toplevel.appId, toplevel.title);
                                }
                              });
        }

        function pushPinned() {
          pinnedApps.forEach(pinnedAppId => {
                               // Find all running instances of this pinned app using robust matching
                               // Also resolve toplevel appId via desktop entry lookup to handle
                               // StartupWMClass != .desktop filename (e.g. zen -> zen-browser-bin)
                               const normalizedPinned = normalizeAppId(pinnedAppId);
                               const matchingToplevels = runningApps.filter(app => {
                                                                              if (!app)
                                                                              return false;
                                                                              if (normalizeAppId(app.appId) === normalizedPinned)
                                                                              return true;
                                                                              const resolved = resolveToDesktopEntryId(app.appId);
                                                                              return resolved !== app.appId && normalizeAppId(resolved) === normalizedPinned;
                                                                            });

                               if (matchingToplevels.length > 0) {
                                 // Add all running instances as pinned-running
                                 matchingToplevels.forEach(toplevel => {
                                                             pushApp("pinned-running", toplevel, pinnedAppId, toplevel.title);
                                                           });
                               } else {
                                 // App is pinned but not running - add once
                                 pushApp("pinned", null, pinnedAppId, getAppNameFromDesktopEntry(pinnedAppId) || pinnedAppId);
                               }
                             });
        }

        //if pinnedStatic then push all pinned and then all remaining running apps
        if (Settings.data.dock.pinnedStatic) {
          pushPinned();
          pushRunning(false);

          //else add all running apps and then remaining pinned apps
        } else {
          pushRunning(true);
          pushPinned();
        }

        const sortedApps = sortDockApps(combined);
        const nextDockApps = buildGroupedDockApps(sortedApps);
        if (!_sameDockApps(nextDockApps, dockApps))
          dockApps = nextDockApps;
        const cycleState = root.groupCycleIndices || {};
        const nextCycleState = {};
        dockApps.forEach(app => {
                           if (app && app.appId && cycleState[app.appId] !== undefined) {
                             nextCycleState[app.appId] = cycleState[app.appId];
                           }
                         });
        root.groupCycleIndices = nextCycleState;

        // Sync session order if needed
        // Instead of resetting everything when length changes, we reconcile the keys
        if (!sessionAppOrder || sessionAppOrder.length === 0) {
          sessionAppOrder = dockApps.map(getAppKey);
        } else {
          const currentKeys = new Set(dockApps.map(getAppKey));
          const existingKeys = new Set();
          const newOrder = [];

          // Keep existing keys that are still present
          sessionAppOrder.forEach(key => {
                                    if (currentKeys.has(key)) {
                                      newOrder.push(key);
                                      existingKeys.add(key);
                                    }
                                  });

          // Add new keys at the end
          dockApps.forEach(app => {
                             const key = getAppKey(app);
                             if (!existingKeys.has(key)) {
                               newOrder.push(key);
                               existingKeys.add(key);
                             }
                           });

          if (JSON.stringify(newOrder) !== JSON.stringify(sessionAppOrder)) {
            sessionAppOrder = newOrder;
          }
        }
      }

      // Hide/show timers — 100 ms in both directions (DESIGN §3.1.4)
      Timer {
        id: hideTimer
        interval: hideDelay
        onTriggered: {
          if (root.dragSourceIndex !== -1)
            return;
          if (!root.currentContextMenu || !root.currentContextMenu.visible)
            root.menuHovered = false;
          if (root.autoHide && !root.dockHovered && !root.anyAppHovered && !root.menuHovered) {
            root.closeAllContextMenus();
            root.hidden = true;
          } else if (root.autoHide && !root.dockHovered) {
            restart();
          }
        }
      }

      Timer {
        id: showTimer
        interval: showDelay
        onTriggered: {
          if (root.autoHide)
            root.hidden = false;
        }
      }

      onAutoHideChanged: {
        hidden = autoHide;
        hideTimer.stop();
        showTimer.stop();
      }

      property alias hideTimer: hideTimer
      property alias showTimer: showTimer

      // ------------------------------------------------------------------
      // Dock window: transparent full-edge layer surface; the input mask is
      // limited to the visual dock rect so clicks pass through outside it.
      // keep-showing reserves screen space; hidden modes don't.
      // ------------------------------------------------------------------
      Loader {
        id: windowLoader
        active: liveScreen && (Settings.data.dock.monitors.length === 0 || Settings.data.dock.monitors.includes(liveScreen.name))

        sourceComponent: PanelWindow {
          id: dockWindow

          screen: root.liveScreen
          focusable: false
          color: "transparent"

          WlrLayershell.namespace: "nosdshell-dock-" + (screen?.name || "unknown")
          WlrLayershell.exclusionMode: root.autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
          // Overlay so the dock keeps drawing above the fullscreen launcher,
          // which sits on Top — the protocol has no layer in between
          // (DESIGN §3.4.1). DDE's dock is always on top as well.
          WlrLayershell.layer: WlrLayer.Overlay

          anchors.top: dockPosition === "top" || isVertical
          anchors.bottom: dockPosition === "bottom" || isVertical
          anchors.left: dockPosition === "left" || !isVertical
          anchors.right: dockPosition === "right" || !isVertical

          // Window covers the full edge; thickness = the dock item thickness
          implicitWidth: isVertical ? itemThickness : 0
          implicitHeight: isVertical ? 0 : itemThickness

          // Window origin in screen coordinates (screen's top-left = 0,0).
          // Layer-shell surfaces can't report their own position, so it's
          // computed from the anchor geometry; PanelService.screenRectOf
          // uses it to place arrow popups and previews over dock items.
          readonly property point screenOrigin: Qt.point(dockPosition === "right" ? (root.liveScreen?.width ?? 0) - itemThickness : 0, dockPosition === "bottom" ? (root.liveScreen?.height ?? 0) - itemThickness : 0)

          // Slide the visual rect off the edge when hidden, leaving a
          // hiddenSliver-thick strip visible on the docked edge.
          readonly property real slideOffset: root.fullscreenCovered ? itemThickness : (root.hidden ? (itemThickness - root.hiddenSliver) : 0)
          readonly property real slideX: dockPosition === "left" ? -slideOffset : dockPosition === "right" ? slideOffset : 0
          readonly property real slideY: dockPosition === "top" ? -slideOffset : dockPosition === "bottom" ? slideOffset : 0

          // Input mask = the visual dock rect only (follows the slide; while
          // hidden this is just the hiddenSliver strip so hovering it reveals
          // the dock, and clicks elsewhere pass through). A fullscreen window
          // swaps in an explicitly EMPTY Region object: on the Overlay layer a
          // stale dock rect would keep claiming the strip's input above the
          // fullscreen window, so release can't depend on per-frame tracking.
          mask: dockInputRegion.region
          NSurfaceRegion {
            id: dockInputRegion

            trackedItem: dockContent.dockContainer
            activeWhen: !root.fullscreenCovered
            // The slide runs through the animated Translate (dockSlide), so
            // the sentinel must be fed the animated values (NSurfaceRegion).
            slideX: dockSlide.x
            slideY: dockSlide.y
          }

          // Blur behind the dock rect (only when the compositor can blur, §1.2).
          // The hidden-state detach (empty-object swap while fullscreenCovered)
          // is NSurfaceRegion's activeWhen.
          BackgroundEffect.blurRegion: Color.blurActive ? dockBlurRegion.region : null
          NSurfaceRegion {
            id: dockBlurRegion

            trackedItem: dockContent.dockContainer
            radius: Style.radiusItem
            activeWhen: !root.fullscreenCovered
            slideX: dockSlide.x
            slideY: dockSlide.y
          }

          DockContent {
            id: dockContent
            anchors.fill: parent
            dockRoot: root
            screenOrigin: dockWindow.screenOrigin

            transform: Translate {
              id: dockSlide
              x: dockWindow.slideX
              y: dockWindow.slideY

              Behavior on x {
                NumberAnimation {
                  duration: Style.motionPanel
                  easing.type: Easing.InOutCubic
                }
              }
              Behavior on y {
                NumberAnimation {
                  duration: Style.motionPanel
                  easing.type: Easing.InOutCubic
                }
              }
            }
          }
        }
      }
    }
  }
}
