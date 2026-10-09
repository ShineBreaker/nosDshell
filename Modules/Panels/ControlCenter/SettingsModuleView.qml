import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Modules.Panels.Settings.Tabs
import qs.Modules.Panels.Settings.Tabs.About
import qs.Modules.Panels.Settings.Tabs.Advanced
import qs.Modules.Panels.Settings.Tabs.Audio
import qs.Modules.Panels.Settings.Tabs.ColorScheme
import qs.Modules.Panels.Settings.Tabs.Connections
import qs.Modules.Panels.Settings.Tabs.ControlCenter
import qs.Modules.Panels.Settings.Tabs.Display
import qs.Modules.Panels.Settings.Tabs.Dock
import qs.Modules.Panels.Settings.Tabs.Hooks
import qs.Modules.Panels.Settings.Tabs.Idle
import qs.Modules.Panels.Settings.Tabs.Launcher
import qs.Modules.Panels.Settings.Tabs.LockScreen
import qs.Modules.Panels.Settings.Tabs.Notifications
import qs.Modules.Panels.Settings.Tabs.Osd
import qs.Modules.Panels.Settings.Tabs.Plugins
import qs.Modules.Panels.Settings.Tabs.Region
import qs.Modules.Panels.Settings.Tabs.SessionMenu
import qs.Modules.Panels.Settings.Tabs.SystemMonitor
import qs.Modules.Panels.Settings.Tabs.UserInterface
import qs.Modules.Panels.Settings.Tabs.Wallpaper
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

/**
* SettingsModuleView - a DDE settings module inside the control center frame
* (DESIGN §3.5.3–3.5.4).
*
* Two columns: a 56 px icon rail (module icons, spacing 20, hover white@0.2,
* selected white@0.3, radiusItem, left-pointing tooltip) and a 352 px content
* column. The content stacks the module's settings tabs; each tab's sub-tabs are
* laid out as SettingsGroups on one scrollable page (NTabBar.groupMode +
* NTabView.stacked) instead of a horizontal pill strip.
*
* The rail and the module mapping live in ControlCenterModules, so the home
* grid, the rail and `settings openTab` routing stay in sync.
*
* `backRequested` fires when the content header's back button is pressed.
*/
Item {
  id: root

  // The highlighted module: rail selection and scroll target. Owners push via
  // openModuleAt; the view never writes an outside binding (see panel/window).
  property var module: null
  // 352 in the frame, 640 in the centered window (DESIGN §3.5.3).
  property real contentWidth: Style.settingsModuleContentWidth

  signal backRequested

  readonly property var modules: ControlCenterModules.modules.filter(m => ControlCenterModules.isVisible(m))
  readonly property string title: I18n.tr("control-center.all-settings")

  // Module visibility can change live (bluetooth adapter); indices shift, so
  // drop lazy state and reload around the current module.
  onModulesChanged: {
    root._loadedMap = ({});
    root._pendingSnap = null;
    snapQuietTimer.stop();
    const i = moduleIndex(module);
    if (i >= 0) {
      _ensureLoaded(i);
      idleFillTimer.start();
    }
  }

  implicitWidth: Style.settingsRailWidth + root.contentWidth
  implicitHeight: sectionsColumn.implicitHeight

  // ---- staged tab loading (DESIGN §3.5.3 perf): the target module and its
  // neighbours load at once, the rest fills in on idle outward from the
  // target (below-first: loading above the viewport shifts content down);
  // unloaded tabs keep an estimated-height placeholder so headers stay put.
  property var _loadedMap: ({})
  property double _openStamp: 0
  property int _targetSec: -1
  // Fill order, rebuilt around every navigation target.
  property var _fillQueue: []

  Timer {
    id: idleFillTimer
    interval: 80
    repeat: true
    onTriggered: root._fillNext()
  }

  function _markLoaded(idx) {
    if (root._loadedMap[idx] === true)
      return;
    const m = Object.assign({}, root._loadedMap);
    m[idx] = true;
    root._loadedMap = m;
  }

  function _ensureLoaded(idx) {
    for (var k = idx - 1; k <= idx + 1; k++) {
      if (k >= 0 && k < modules.length)
        _markLoaded(k);
    }
    _rebuildFillQueue(idx);
  }

  // Order module indices by distance from the navigation target so the
  // viewport neighbourhood settles first.
  function _rebuildFillQueue(center) {
    const c = (center >= 0 && center < modules.length) ? center : 0;
    const order = [];
    for (var i = 0; i < modules.length; i++)
      order.push(i);
    order.sort((a, b) => {
                 const d = Math.abs(a - c) - Math.abs(b - c);
                 if (d !== 0)
                 return d;
                 if ((a > c) !== (b > c))
                 return (a > c) ? -1 : 1;
                 return a - b;
               });
    root._fillQueue = order;
  }

  function _tabActive(mIdx) {
    return root._loadedMap[mIdx] === true;
  }

  function _fillNext() {
    const q = root._fillQueue;
    for (var k = 0; k < q.length; k++) {
      const qi = q[k];
      if (qi >= 0 && qi < modules.length && root._loadedMap[qi] !== true) {
        _markLoaded(qi);
        return;
      }
    }
    for (var i = 0; i < modules.length; i++) {
      if (root._loadedMap[i] !== true) {
        _markLoaded(i);
        return;
      }
    }
    idleFillTimer.stop();
    // NOTE: do NOT drop _pendingSnap here — flags are set but asynchronous
    // instantiation may still be in flight; the snap clears once the target
    // and everything above it are really Ready (see _onTabLoaded).
  }

  // ---- programmatic scroll (nav click / routing) ----
  property bool _programmatic: false
  // Re-snap target while lazy tabs still load: {sec, tab}. Cleared on user
  // scroll, or once the target section and everything above it are Ready
  // (only then is the target Y final).
  property var _pendingSnap: null
  property bool _snapLogged: false
  // True while we set contentY ourselves (re-snap): keeps onContentYChanged
  // from mistaking our own writes for user scrolls.
  property bool _snapping: false

  NumberAnimation {
    id: scrollAnim
    // target is assigned lazily in _scrollToY: contentScroll is declared
    // later in this file, so a declarative binding here risks evaluating
    // before its contentItem exists.
    property: "contentY"
    duration: Style.motionSettingsScroll
    easing.type: Easing.OutQuint
    onFinished: {
      root._programmatic = false;
      root._settleSnap();
    }
  }

  function _cancelProgrammatic() {
    if (scrollAnim.running)
      scrollAnim.stop();
    root._programmatic = false;
    root._pendingSnap = null;
    snapQuietTimer.stop();
  }

  // User scroll stopped (short debounce) → highlight the first module whose
  // header top sits at/below the viewport top (settingswidget.cpp:342-380).
  // The current module is kept while its section still intersects the
  // viewport (same hysteresis as the C++ early-return). Deviation: past the
  // last header the C++ falls back to the first activable module; here the
  // last visible section stays highlighted instead of jumping to the top.
  Timer {
    id: scrollSettleTimer
    interval: 180
    repeat: false
    onTriggered: root._syncModuleToScroll()
  }

  // Final alignment: fires after a quiet period with no tab loads (covers
  // late shifts like font-driven height changes that arrive after every
  // Loader already reported Ready). Re-armed by openModuleAt and every load.
  Timer {
    id: snapQuietTimer
    interval: 1500
    repeat: false
    onTriggered: {
      root._resnapToTarget();
      root._pendingSnap = null;
    }
  }

  function _syncModuleToScroll() {
    if (root._programmatic || modules.length === 0)
      return;
    const f = _flickable();
    if (!f)
      return;
    const top = f.contentY;
    const cur = moduleIndex(module);
    if (cur >= 0) {
      const s = sectionsRepeater.itemAt(cur);
      if (s && s.y < top + f.height && s.y + s.height > top)
        return;
    }
    var first = -1;
    for (var i = 0; i < modules.length; i++) {
      const it = sectionsRepeater.itemAt(i);
      if (!it)
        continue;
      if (it.y >= top - 1) {
        first = i;
        break;
      }
    }
    if (first < 0) {
      for (var j = modules.length - 1; j >= 0; j--) {
        const jt = sectionsRepeater.itemAt(j);
        if (jt && jt.y < top + f.height) {
          first = j;
          break;
        }
      }
      if (first < 0)
        return;
    }
    if (modules[first] !== module)
      module = modules[first];
  }

  function _flickable() {
    return contentScroll.contentItem;
  }

  function _clampY(y) {
    const f = _flickable();
    if (!f)
      return 0;
    return Math.max(0, Math.min(y, Math.max(0, f.contentHeight - f.height)));
  }

  // Y of a module header / tab slot inside the scroll content.
  function _sectionY(i) {
    const s = sectionsRepeater.itemAt(i);
    return s ? s.y : 0;
  }

  // j = tab-slot index inside the module; inner = sub-group index inside
  // that tab's stacked NTabView (-1 = slot top).
  function _tabSlotY(i, j, inner) {
    const s = sectionsRepeater.itemAt(i);
    if (!s || typeof s.tabSlotY !== "function")
      return _sectionY(i);
    var y = s.tabSlotY(j);
    if (inner > 0 && typeof s.innerSlotY === "function")
      y += s.innerSlotY(j, inner);
    return s.y + y;
  }

  function _scrollToY(y, animated) {
    const f = _flickable();
    if (!f)
      return;
    y = _clampY(y);
    scrollAnim.stop();
    if (animated && Style.motionSettingsScroll > 0 && Math.abs(f.contentY - y) > 1) {
      root._programmatic = true;
      scrollAnim.target = f;
      scrollAnim.to = y;
      scrollAnim.start();
    } else {
      root._programmatic = false;
      root._snapping = true;
      f.contentY = y;
      root._snapping = false;
    }
  }

  function _scrollToSection(i, subTab, inner, animated) {
    var tab = (subTab === undefined || subTab === null) ? -1 : subTab;
    var innerIdx = (inner === undefined || inner === null) ? -1 : inner;
    // Slot 0 with no inner group == "the module": keep its header in view.
    const y = (tab > 0 || innerIdx > 0) ? _tabSlotY(i, tab, innerIdx) : _sectionY(i);
    root._pendingSnap = {
      "sec": i,
      "tab": tab,
      "inner": innerIdx
    };
    _scrollToY(y, animated);
    // Already fully loaded (e.g. reopening): settle immediately.
    _onTabLoaded(i);
  }

  // Called by every tab Loader when it finishes: while a snap target is
  // pending, keep its header stable as heights above or below it still change.
  // The snap is cleared only by user scroll, a new open, module changes, or
  // the quiet timer — never by load bookkeeping: any late height shift
  // (placeholder estimate taller than the real tab collapses contentHeight,
  // Flickable clamps contentY down) must still find the target waiting.
  function _onTabLoaded(secIdx) {
    // Open-latency probe, independent of the re-snap lifecycle.
    if (secIdx === root._targetSec && !root._snapLogged) {
      const t = sectionsRepeater.itemAt(secIdx);
      if (t && t.tabsReady && t.tabsReady()) {
        root._snapLogged = true;
        Logger.i("SettingsModule", "all-settings open: target ready in", (Date.now() - root._openStamp) + "ms");
      }
    }
    const snap = root._pendingSnap;
    if (!snap)
      return;
    snapQuietTimer.restart();
    _resnapToTarget();
  }

  // Move contentY onto the pending target when it drifted off by more
  // than a pixel, either direction. Called after loads and when the scroll
  // animation settles.
  function _resnapToTarget() {
    const snap = root._pendingSnap;
    if (!snap)
      return;
    const inner = snap.inner ?? -1;
    const y = _clampY((snap.tab > 0 || inner > 0) ? _tabSlotY(snap.sec, snap.tab, inner) : _sectionY(snap.sec));
    if (scrollAnim.running) {
      scrollAnim.to = y;
      return;
    }
    const f = _flickable();
    if (f && Math.abs(f.contentY - y) > 1) {
      root._snapping = true;
      f.contentY = y;
      root._snapping = false;
    }
  }

  // Settle check after the scroll animation ends: loads that finished
  // mid-flight may have moved the target since `to` was computed.
  function _settleSnap() {
    if (root._pendingSnap)
      _resnapToTarget();
  }

  function selectModule(mod) {
    openModuleAt(mod, -1);
  }

  function searchResultClicked(entry) {
    const t = ControlCenterModules.targetForTab(entry.tab, entry.subTab);
    if (t)
      openModuleAt(t.module, t.slot, t.inner, false);
    searchInput.text = "";
  }

  // External entry point for routing (panel openModule, window navigateTo)
  // and in-page navigation (rail clicks, keyboard, search results):
  // highlight + scroll to the module header, to a tab section when
  // subTab >= 0, and to a stacked sub-group inside that tab when inner > 0.
  // Routing passes animated=false so a freshly opened page lands directly
  // on the target; only in-page navigation plays the scroll animation.
  function openModuleAt(mod, subTab, inner, animated) {
    if (!mod)
      return;
    const idx = moduleIndex(mod);
    if (idx < 0)
      return;
    root._openStamp = Date.now();
    root._snapLogged = false;
    root._targetSec = idx;
    module = modules[idx];
    _ensureLoaded(idx);
    idleFillTimer.start();
    snapQuietTimer.start();
    Qt.callLater(() => _scrollToSection(idx, subTab, inner, animated !== false));
  }

  // modelData reaching delegates may be a QVariant-wrapped copy (Repeater
  // converts JS-object models), so identity can fail; compare by id.
  function moduleIndex(mod) {
    if (!mod)
      return -1;
    for (var i = 0; i < modules.length; i++) {
      if (modules[i] === mod || modules[i].id === mod.id)
        return i;
    }
    return -1;
  }

  function selectNextModule() {
    const i = moduleIndex(module);
    if (i >= 0 && i + 1 < modules.length)
      openModuleAt(modules[i + 1], -1);
  }

  // Tab enum -> Loader component (shared by every module section).
  function _tabComponent(tab) {
    switch (tab) {
    case SettingsPanel.Tab.About:
      return aboutTab;
    case SettingsPanel.Tab.Advanced:
      return advancedTab;
    case SettingsPanel.Tab.Audio:
      return audioTab;
      // NOTE: Tab.Bar has no owning module (no ControlCenterModules entry maps
      // it) and no BarTab component exists — the only producer is the IPC
      // `settings openTab bar` shim, which targetForTab already rejects. The
      // enum item itself stays: ordinals are persisted (search index) and
      // Services/Control/IPCService.qml still references it.
    case SettingsPanel.Tab.ColorScheme:
      return colorSchemeTab;
    case SettingsPanel.Tab.LockScreen:
      return lockScreenTab;
    case SettingsPanel.Tab.ControlCenter:
      return controlCenterTab;
    case SettingsPanel.Tab.DesktopWidgets:
      return desktopWidgetsTab;
    case SettingsPanel.Tab.OSD:
      return osdTab;
    case SettingsPanel.Tab.Display:
      return displayTab;
    case SettingsPanel.Tab.Dock:
      return dockTab;
    case SettingsPanel.Tab.General:
      return generalTab;
    case SettingsPanel.Tab.Hooks:
      return hooksTab;
    case SettingsPanel.Tab.Idle:
      return idleTab;
    case SettingsPanel.Tab.Launcher:
      return launcherTab;
    case SettingsPanel.Tab.Location:
      return regionTab;
    case SettingsPanel.Tab.Connections:
      return connectionsTab;
    case SettingsPanel.Tab.Notifications:
      return notificationsTab;
    case SettingsPanel.Tab.Plugins:
      return pluginsTab;
    case SettingsPanel.Tab.SessionMenu:
      return sessionMenuTab;
    case SettingsPanel.Tab.System:
      return systemMonitorTab;
    case SettingsPanel.Tab.UserInterface:
      return userInterfaceTab;
    case SettingsPanel.Tab.Wallpaper:
      return wallpaperTab;
    }
    return aboutTab;
  }

  function selectPreviousModule() {
    const i = moduleIndex(module);
    if (i > 0)
      openModuleAt(modules[i - 1], -1);
  }

  // Keyboard scrolling for the standalone panel/window surfaces
  // (SettingsPanel's SmartPanel keymap delegates here).
  function scrollBy(dy) {
    const f = _flickable();
    if (f)
      _scrollToY(_clampY(f.contentY + dy), true);
  }

  function scrollDown() {
    scrollBy(Style.margin2L * 4);
  }

  function scrollUp() {
    scrollBy(-Style.margin2L * 4);
  }

  function scrollPageDown() {
    scrollBy(contentScroll.height * 0.8);
  }

  function scrollPageUp() {
    scrollBy(-contentScroll.height * 0.8);
  }

  // Search field state + result selection for the panel's Up/Down keys.
  readonly property alias searchText: searchInput.text

  function searchSelectNext() {
    searchResults.incrementCurrentIndex();
  }

  function searchSelectPrevious() {
    searchResults.decrementCurrentIndex();
  }

  // Sub-tabs of a tab are shown as SettingsGroups on one scrollable page
  // (DESIGN §3.5.3): find the tab's NTabBar / NTabView by objectName and flip
  // both into group mode. objectName lookup keeps tab files untouched.
  function _applyGroupMode(tabItem) {
    if (!tabItem)
      return;
    const bar = _findByObjectName(tabItem, "NTabBar");
    const view = _findByObjectName(tabItem, "NTabView");
    if (bar)
      bar.groupMode = true;
    if (view)
      view.stacked = true;
  }

  function _findByObjectName(item, name) {
    if (!item || !item.children)
      return null;
    for (var i = 0; i < item.children.length; i++) {
      const child = item.children[i];
      if (child.objectName === name)
        return child;
      const found = _findByObjectName(child, name);
      if (found)
        return found;
    }
    return null;
  }

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // ---------------- left rail (56 px) ----------------
    Rectangle {
      Layout.preferredWidth: Style.settingsRailWidth
      Layout.fillHeight: true
      color: "transparent"

      NScrollView {
        id: railScroll
        anchors.fill: parent
        anchors.topMargin: Style.marginS
        anchors.bottomMargin: Style.marginS
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        showGradientMasks: false
        ScrollBar.vertical.visible: false
        // The flickable must never grab presses: a real mouse jitters a few
        // pixels during a click, the flickable interprets it as a drag start
        // and eats the click. Wheel scrolling still works via WheelHandler.
        flickableInteractive: false

        Column {
          width: parent.width
          spacing: 0

          // Button group stays vertically centred; spacers collapse when
          // the buttons overflow (navigationbar.cpp: centralLayout stretches).
          Item {
            width: 1
            height: Math.max(0, (railScroll.height - railButtons.height) / 2)
          }

          Column {
            id: railButtons
            width: parent.width
            spacing: Style.settingsRailSpacing

            Repeater {
              model: root.modules

              delegate: Item {
                id: railDelegate
                required property var modelData
                required property int index

                readonly property bool selected: root.module !== null && modelData !== null && root.module.id === modelData.id
                readonly property string ddeArt: ControlCenterModules.navIconUrl(modelData, selected)

                width: Style.settingsRailWidth
                height: Style.settingsModuleHeadIcon + 2 * Style.settingsRailButtonPadV

                // The whole 56 px column cell is clickable (the visible tile
                // is narrower); the side insets must not be dead zones.
                MouseArea {
                  id: railArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: TooltipService.show(railDelegate, ControlCenterModules.tr(modelData.label), "left")
                  onExited: TooltipService.hide()
                  onClicked: root.selectModule(modelData)
                }

                Rectangle {
                  anchors.centerIn: parent
                  width: Style.settingsRailWidth - 2 * Style.settingsRailButtonMarginH
                  height: parent.height
                  radius: Style.radiusRow
                  color: {
                    if (railArea.containsMouse)
                      return Color.overlay("strong");
                    if (selected)
                      return Color.overlay("checked");
                    return "transparent";
                  }

                  Behavior on color {
                    enabled: !Color.isTransitioning
                    ColorAnimation {
                      duration: Style.animationFast
                    }
                  }

                  Image {
                    id: railArt
                    anchors.centerIn: parent
                    width: Style.settingsModuleHeadIcon
                    height: Style.settingsModuleHeadIcon
                    sourceSize.width: Math.round(Style.settingsModuleHeadIcon * Style.uiScaleRatio)
                    sourceSize.height: Math.round(Style.settingsModuleHeadIcon * Style.uiScaleRatio)
                    source: ddeArt
                    visible: ddeArt !== "" && status !== Image.Error
                    smooth: true
                  }

                  NIcon {
                    anchors.centerIn: parent
                    icon: modelData.icon
                    // Same size as the DDE artwork box (module head fallback
                    // uses this too) so the rail column reads uniform.
                    pointSize: Style.settingsModuleHeadIcon
                    applyUiScale: false
                    visible: !railArt.visible
                    // Unselected rail glyph is dimmed on-shell ink — the DDE
                    // spec is white@0.4 on the dark frame; on a light frame
                    // the same alpha is applied to #303030 with a bit more
                    // weight (0.6) so the icon survives on the light rail.
                    color: selected ? Color.onShell : Qt.alpha(Color.onShell, Color.shellIsDark ? Style.settingsRailIconDim : 0.6)
                  }
                }
              }
            }
          }

          Item {
            width: 1
            height: Math.max(0, (railScroll.height - railButtons.height) / 2)
          }
        }
      }
    }

    // ---------------- content (352 px in the frame, 640 in the window) ----------------
    Item {
      Layout.preferredWidth: root.contentWidth
      Layout.fillHeight: true
      clip: true

      ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 0

        // Header: back button, centred title, separator 15 px below (DESIGN §3.5.3)
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize + Style.marginS

          NIconButton {
            id: backButton
            anchors.left: parent.left
            anchors.leftMargin: Style.marginS
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron-left"
            // 24×24, radius 4, white×0.2 block (DESIGN §3.5.3).
            baseSize: 24
            customRadius: Style.radiusRow
            colorBg: Color.overlay("strong")
            tooltipText: I18n.tr("common.back")
            onClicked: root.backRequested()
          }

          NText {
            anchors.left: backButton.right
            anchors.right: parent.right
            anchors.rightMargin: backButton.width + backButton.anchors.leftMargin
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            pointSize: Style.settingsModuleTitleSize
            font.weight: Style.fontWeightMedium
            color: Color.onShell
            elide: Text.ElideRight
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.borderS
          Layout.leftMargin: Style.settingsRowPaddingH
          Layout.rightMargin: Style.settingsRowPaddingH
          Layout.bottomMargin: Style.settingsModuleSeparatorGap
          color: Color.separator
        }

        // Search (DESIGN §3.5.4 input: height 30, bg field, radiusItem, focus
        // 1 px accent). Noctalia's search index has no DDE counterpart; the
        // field lives in the module view so every mode keeps working.
        Rectangle {
          id: searchField
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
          Layout.rightMargin: Style.marginS
          Layout.bottomMargin: Style.marginS
          Layout.preferredHeight: Style.settingsFieldHeight
          radius: Style.radiusItem
          color: Color.overlay("field")
          border.width: searchInput.activeFocus ? Style.borderS : 0
          border.color: Color.accent

          NIcon {
            anchors.left: parent.left
            anchors.leftMargin: Style.marginS
            anchors.verticalCenter: parent.verticalCenter
            icon: "search"
            pointSize: Style.fontSizeTitle
            color: Color.onShellSecondary
          }

          TextInput {
            id: searchInput
            objectName: "settingsSearchInput"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Style.margin2S
            anchors.rightMargin: Style.marginS
            verticalAlignment: Text.AlignVCenter
            leftPadding: Style.margin2S
            color: Color.onShell
            font.pointSize: Style.fontSizeBody
            selectByMouse: true
            onAccepted: {
              if (searchResults.count > 0)
                searchResults.selectFirst();
            }
          }
        }

        // All visible modules stacked in one scroll area (DESIGN §3.5.3): every
        // module opens with its header, then its tabs as groups.
        NScrollView {
          id: contentScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.leftMargin: Style.marginS
          Layout.rightMargin: Style.marginS
          Layout.bottomMargin: Style.marginM
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          reserveScrollbarSpace: false
          showGradientMasks: false
          gradientColor: Color.maskShell

          // User scroll cancels programmatic scroll + pending re-snap; scroll
          // stops (debounced) sync the rail highlight (commit: nav sync).
          // NOTE: contentY also changes when Flickable auto-clamps after the
          // content above shrinks (placeholder estimate taller than the real
          // tab). That is NOT user intent, so the snap must survive it — the
          // pending target is dropped only on explicit drag/flick/wheel.
          Connections {
            target: contentScroll.contentItem
            function onDraggingChanged() {
              if (contentScroll.contentItem.dragging)
                root._cancelProgrammatic();
            }
            function onFlickingChanged() {
              if (contentScroll.contentItem.flicking)
                root._cancelProgrammatic();
            }
            function onContentYChanged() {
              if (root._programmatic || root._snapping)
                return;
              scrollSettleTimer.restart();
            }
            // Any height shift (late font/image/layout polish that arrives with
            // no Loader event) moves the pending target: re-snap while the user
            // is not dragging. This is what finally closes shrink-clamp drift.
            function onContentHeightChanged() {
              const f = contentScroll.contentItem;
              if (!root._pendingSnap || !f || f.dragging || f.flicking)
                return;
              root._resnapToTarget();
            }
          }

          // Wheel takeover: NScrollView consumes the event for smooth scrolling;
          // this sibling handler only cancels our programmatic state (it never
          // accepts, so default processing continues untouched).
          WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: root._cancelProgrammatic()
          }

          Column {
            id: sectionsColumn
            width: parent.width
            spacing: Style.settingsGroupSpacing

            Repeater {
              id: sectionsRepeater
              model: root.modules

              delegate: Column {
                required property var modelData
                required property int index
                readonly property var sectionModule: modelData
                readonly property int sectionIndex: index
                // Original nav art for the header (selected variant); "" → Tabler.
                readonly property string headArt: ControlCenterModules.navIconUrl(sectionModule, true)
                width: sectionsColumn.width
                spacing: Style.marginS

                // Y of a tab slot for subTab scrolling.
                function tabSlotY(j) {
                  const t = tabsRepeater.itemAt(j);
                  return t ? t.y : 0;
                }
                // Y of stacked sub-group `inner` inside tab slot `j`, relative
                // to the slot top (0 when the tab has no stacked view).
                function innerSlotY(j, inner) {
                  const t = tabsRepeater.itemAt(j);
                  const view = t ? t.stackedView() : null;
                  return view ? view.groupOffset(inner) : 0;
                }
                // Every tab slot loaded?
                function tabsReady() {
                  for (var k = 0; k < tabsRepeater.count; k++) {
                    const t = tabsRepeater.itemAt(k);
                    if (!t || !t.tabReady())
                      return false;
                  }
                  return true;
                }

                // Module header: left 11, 24 icon, large white title,
                // 5 px vertical padding (modulewidget.cpp).
                Item {
                  width: parent.width
                  height: Style.settingsModuleHeadIcon + 2 * Style.settingsModuleHeadPadV
                  Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.settingsModuleHeadLeft
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.marginS
                    Image {
                      id: headArtImage
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.settingsModuleHeadIcon
                      height: Style.settingsModuleHeadIcon
                      sourceSize.width: Math.round(Style.settingsModuleHeadIcon * Style.uiScaleRatio)
                      sourceSize.height: Math.round(Style.settingsModuleHeadIcon * Style.uiScaleRatio)
                      source: headArt
                      visible: headArt !== "" && status !== Image.Error
                      smooth: true
                    }
                    NIcon {
                      anchors.verticalCenter: parent.verticalCenter
                      icon: sectionModule.icon
                      pointSize: Style.settingsModuleHeadIcon
                      applyUiScale: false
                      visible: !headArtImage.visible
                      color: Color.onShell
                    }
                    NText {
                      anchors.verticalCenter: parent.verticalCenter
                      text: ControlCenterModules.tr(sectionModule.label)
                      pointSize: Style.fontSizeXL
                      color: Color.onShell
                    }
                  }
                }

                Repeater {
                  id: tabsRepeater
                  model: sectionModule.tabs ?? [sectionModule]

                  delegate: Item {
                    id: tabSlot
                    required property var modelData
                    required property int index
                    width: sectionsColumn.width
                    // The loaded item only reports its real height once the
                    // tab's stacked NTabView has collected its pages (its
                    // _initializeItems runs one turn after incubation); before
                    // that the item reads a collapsed mid-layout height. Keep
                    // the estimate and hide the content until then so the
                    // column swaps estimate->real in a single step.
                    property bool _contentReady: false
                    implicitHeight: (_contentReady && tabLoader.item) ? tabLoader.item.implicitHeight : Style.settingsTabEstimateHeight

                    function tabReady() {
                      return _contentReady;
                    }
                    // The tab's internal NTabView once loaded (null before /
                    // when the component has none). Used for inner sub-group
                    // scroll targets.
                    function stackedView() {
                      return tabLoader.item ? root._findByObjectName(tabLoader.item, "NTabView") : null;
                    }

                    Connections {
                      id: readyConn
                      enabled: false
                      function onInitializedChanged() {
                        if (readyConn.target && readyConn.target.initialized) {
                          tabSlot._contentReady = true;
                          readyConn.enabled = false;
                        }
                      }
                    }

                    Loader {
                      id: tabLoader
                      width: parent.width
                      asynchronous: true
                      active: root._tabActive(sectionIndex)
                      sourceComponent: root._tabComponent(modelData.tab)
                      visible: tabSlot._contentReady

                      onActiveChanged: {
                        if (!active) {
                          tabSlot._contentReady = false;
                          readyConn.enabled = false;
                          readyConn.target = null;
                        }
                      }

                      onLoaded: {
                        if (item === null)
                          return;
                        root._applyGroupMode(item);
                        const view = root._findByObjectName(item, "NTabView");
                        if (!view || view.initialized) {
                          tabSlot._contentReady = true;
                        } else {
                          readyConn.target = view;
                          readyConn.enabled = true;
                        }
                        // NOTE: no currentSubTabIndex preselect — tab files have no
                        // such property (the old line only ever errored); subTab
                        // routing scrolls to the tab section instead.
                        root._onTabLoaded(sectionIndex);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Search-result popup. Sibling of contentLayout, not a child of the
      // fixed-height field: pointer delivery walks "child contains point" down
      // the tree, so anything painted past the field's own rect can never take
      // a press no matter the z — the scroll view underneath wins every time.
      // Anchored under searchField so it floats above the module scroll view;
      // popupShell keeps the overlay-tinted rows legible over the glass content.
      Rectangle {
        id: searchPopup
        objectName: "settingsSearchPopup"
        x: searchField.x
        y: searchField.y + searchField.height + Style.marginXS
        width: searchField.width
        height: Math.min(searchResults.contentHeight, Style.controlCenterWidth)
        visible: searchResults.count > 0 && searchInput.text.trim() !== ""
        radius: Style.radiusPopup
        color: Color.popupShell
        border.color: Color.borderShell
        border.width: Style.borderS
        clip: true

        ListView {
          id: searchResults
          anchors.fill: parent
          clip: true
          // Explicit highlight kept under the delegates — Qt's default highlight
          // item sits above row 0 and swallows its clicks
          highlight: Rectangle {
            color: Color.overlay("checked")
            radius: Style.radiusRow
            z: -1
          }
          highlightMoveDuration: Style.animationFast
          model: SettingsSearchService.searchIndex.filter(function (entry) {
            return SettingsSearchService.isEntryVisible(entry) && searchInput.text.trim() !== "" && I18n.tr(entry.labelKey).toLowerCase().includes(searchInput.text.trim().toLowerCase());
          })

          // Up/Down + Enter from the field: first result selected by default
          onCountChanged: {
            if (count > 0 && currentIndex < 0)
              currentIndex = 0;
          }

          function selectFirst() {
            if (currentItem)
              searchResultClicked(currentItem.entry);
          }

          delegate: NDccRow {
            required property var modelData
            required property int index
            readonly property var entry: modelData
            width: searchResults.width
            height: Style.detailRowHeight
            clickable: true
            onHoveredChanged: {
              if (hovered)
                searchResults.currentIndex = index;
            }
            onClicked: searchResultClicked(entry)

            NText {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              text: I18n.tr(entry.labelKey)
              pointSize: Style.fontSizeBody
              color: Color.onShell
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }

  Component {
    id: aboutTab
    AboutTab {}
  }
  Component {
    id: advancedTab
    AdvancedTab {}
  }
  Component {
    id: audioTab
    AudioTab {}
  }
  Component {
    id: colorSchemeTab
    ColorSchemeTab {}
  }
  Component {
    id: lockScreenTab
    LockScreenTab {}
  }
  Component {
    id: controlCenterTab
    ControlCenterTab {}
  }
  Component {
    id: desktopWidgetsTab
    DesktopWidgetsTab {}
  }
  Component {
    id: osdTab
    OsdTab {}
  }
  Component {
    id: displayTab
    DisplayTab {}
  }
  Component {
    id: dockTab
    DockTab {}
  }
  Component {
    id: generalTab
    GeneralTab {}
  }
  Component {
    id: hooksTab
    HooksTab {}
  }
  Component {
    id: idleTab
    IdleTab {}
  }
  Component {
    id: launcherTab
    LauncherTab {}
  }
  Component {
    id: regionTab
    RegionTab {}
  }
  Component {
    id: connectionsTab
    ConnectionsTab {}
  }
  Component {
    id: notificationsTab
    NotificationsTab {}
  }
  Component {
    id: pluginsTab
    PluginsTab {}
  }
  Component {
    id: sessionMenuTab
    SessionMenuTab {}
  }
  Component {
    id: systemMonitorTab
    SystemMonitorTab {}
  }
  Component {
    id: userInterfaceTab
    UserInterfaceTab {}
  }
  Component {
    id: wallpaperTab
    WallpaperTab {}
  }

  // Keep-alive panels preload this view while hidden (SmartPanel
  // contentLoader): start the staged tab fill at creation too, so the first
  // open lands on settled rows instead of a 3 s placeholder sweep.
  Component.onCompleted: {
    if (module === null && modules.length > 0) {
      _ensureLoaded(0);
      idleFillTimer.start();
    }
  }
}
