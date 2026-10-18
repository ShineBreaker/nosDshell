import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Compositor
import qs.Services.Debug
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// DDE 15 fashion dock content (DESIGN §3.1.1/§3.1.2, gxde-dock mainpanel):
// launcher item -> pinned + running apps -> 6 px slit -> plugin area.
// Items are itemLength x itemThickness with a centered icon of
// 0.8 * min(w, h); running indicators are 20x2 (2x20 vertical) bars on the
// screen-edge side; active = accent with fading ends; attention = swing +
// attention color. Overflow shrinks items proportionally (mainpanel.cpp:623-698).
Item {
  id: dock

  required property var dockRoot
  property alias dockContainer: dockContainer

  // Screen-space origin of the hosting window, assigned by Dock.qml.
  // PanelService.screenRectOf walks the parent chain to find it.
  property point screenOrigin: Qt.point(0, 0)

  // Edge of the dock surface on the same chain — PanelService.surfaceEdgeOf
  // (always the taskbar edge; the floating dock has no status-bar role).
  readonly property string hostEdge: dockRoot ? dockRoot.dockPosition : ""

  // Dock.qml passes the ShellScreen as modelData. liveScreen wins: the
  // injected modelData can be a stale ShellScreen with frozen dimensions
  // (PanelService.liveScreen).
  readonly property var screen: dockRoot ? (dockRoot.liveScreen || dockRoot.modelData || dockRoot.screen || null) : null
  readonly property bool isVertical: dockRoot.isVertical
  readonly property string tooltipDirection: dockRoot.dockPosition === "left" ? "right" : (dockRoot.dockPosition === "right" ? "left" : (dockRoot.dockPosition === "top" ? "bottom" : "top"))
  readonly property int itemSpacing: Style.marginXXS

  // Fashion dock content = dock.taskbarWidgets.left ++ center ++
  // dock.plugins, one flat strip — the same lists the taskbar-mode editor
  // (PluginsSubTab, §3.5.3) writes, so every item is repositionable and the
  // same arrangement carries across modes. Launcher/Taskbar/Spacer render as
  // their own item segments; every other registered id joins a capsule-tile
  // plugin run — one tile per contiguous run, same look as before.
  readonly property var contentList: {
    var zones = Settings.data.dock.taskbarWidgets;
    var lists = [zones ? zones.left : null, zones ? zones.center : null, Settings.data.dock.plugins];
    var out = [];
    for (var li = 0; li < lists.length; li++) {
      var list = lists[li] || [];
      for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (e && e.id)
          out.push(e);
      }
    }
    return out;
  }

  readonly property var contentSegments: {
    // Depend on the registry generation: plugin widgets register after this
    // binding first evaluates, and hasWidget() alone is not a dependency.
    var _gen = BarWidgetRegistry.generation;
    var segs = [];
    var run = null;
    function flush() {
      if (run) {
        segs.push(run);
        run = null;
      }
    }
    for (var i = 0; i < contentList.length; i++) {
      var entry = contentList[i];
      var id = entry.id;
      if (id === "Launcher" || id === "Taskbar" || id === "Spacer") {
        flush();
        segs.push({
                    "kind": "item",
                    "_tag": "s" + segs.length,
                    "entry": entry
                  });
      } else if (BarWidgetRegistry.hasWidget(id)) {
        if (!run)
          run = {
            "kind": "plugins",
            "_tag": "s" + segs.length,
            "entries": []
          };
        run.entries.push(entry);
      }
      // Unregistered ids drop entirely — the old pluginList skipped them the
      // same way (a candidate that renders nowhere was the "Workspace added
      // but invisible" bug class).
    }
    flush();
    return segs;
  }

  // Measured long-axis length of each segment's rendered item, keyed by the
  // segment tag — plugin tiles hold variable-width widgets (expanded tray
  // pill, clock), so estimating cellSize under-reports and clips them.
  property var segLens: ({})
  function _noteSegLen(tag, len) {
    if (segLens[tag] === len)
      return;
    var m = {};
    for (var k in segLens)
      m[k] = segLens[k];
    if (len > 0)
      m[tag] = len;
    segLens = m;
  }
  function _segLen(seg) {
    var m = segLens[seg._tag];
    if (m !== undefined)
      return m;
    if (seg.kind === "plugins") {
      var n = seg.entries.length;
      var fusedPad = Settings.data.dock.fusedPlugins ? Style.marginXS * 2 : 0;
      return n * (Style.dockPluginTileSize + itemSpacing) + fusedPad + Style.marginS + itemSpacing;
    }
    return dockRoot.itemLength;
  }

  // Proportional shrink when the dock would exceed maxLength
  // (gxde-dock mainpanel.cpp:623-698). Plugin tiles keep their natural
  // length; app items (and the launcher slot) absorb the deficit.
  readonly property real shrinkFactor: {
    var segs = contentSegments;
    var shrinkUnits = 0;
    var fixedLen = 0;
    for (var i = 0; i < segs.length; i++) {
      var s = segs[i];
      if (s.kind === "plugins") {
        fixedLen += _segLen(s);
      } else if (s.entry.id === "Taskbar") {
        shrinkUnits += dockRoot.dockApps.length;
      } else {
        shrinkUnits += 1; // Launcher, Spacer — app-item-sized slots
      }
    }
    var gaps = Math.max(0, segs.length - 1) * itemSpacing;
    var needed = shrinkUnits * (dockRoot.itemLength + itemSpacing) + gaps + fixedLen;
    if (needed <= dockRoot.maxLength)
      return 1;
    var availPerApp = (dockRoot.maxLength - fixedLen - gaps) / Math.max(1, shrinkUnits) - itemSpacing;
    return Math.max(0.4, availPerApp / dockRoot.itemLength);
  }

  function getAppIcon(appData): string {
    if (!appData || !appData.appId)
      return "";
    return ThemeIcons.iconForAppId(appData.appId);
  }

  function getValidToplevels(appData) {
    if (!appData || !ToplevelManager || !ToplevelManager.toplevels)
      return [];
    const source = appData.toplevels && appData.toplevels.length > 0 ? appData.toplevels : (appData.toplevel ? [appData.toplevel] : []);
    const allToplevels = ToplevelManager.toplevels.values || [];
    return source.filter(toplevel => toplevel && allToplevels.includes(toplevel));
  }

  function getPrimaryToplevel(appData) {
    const toplevels = getValidToplevels(appData);
    if (toplevels.length === 0)
      return null;
    if (ToplevelManager && ToplevelManager.activeToplevel && toplevels.includes(ToplevelManager.activeToplevel))
      return ToplevelManager.activeToplevel;
    return toplevels[0];
  }

  function isUrgent(appData) {
    const toplevels = getValidToplevels(appData);
    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i];
      if (t && (t.urgent === true || t.urgent === "true"))
        return true;
    }
    return false;
  }

  function launchAppById(appId) {
    if (!appId)
      return;

    const app = ThemeIcons.findAppEntry(appId);
    if (!app) {
      Logger.w("Dock", `Could not find desktop entry for pinned app: ${appId}`);
      return;
    }

    CompositorService.launchDesktopEntry(app);
  }

  // Volunteer this scene for DebugService dumps/destruction watches
  // (qs ipc call debug tree|watch dock-<screen>). The screen binding may
  // still be null at Component.onCompleted — register when it lands.
  property string _dbgName: ""
  onScreenChanged: {
    if (screen?.name && _dbgName === "") {
      _dbgName = "dock-" + screen.name;
      DebugService.registerRoot(_dbgName, dock);
    }
  }
  Component.onDestruction: {
    if (_dbgName !== "") {
      DebugService.unregisterRoot(_dbgName);
    }
  }

  // Hover bookkeeping shared by every interactive item
  function itemEntered() {
    dockRoot.anyAppHovered = true;
    if (dockRoot.autoHide) {
      dockRoot.showTimer.stop();
      dockRoot.hideTimer.stop();
      dockRoot.hidden = false;
    }
  }

  function itemExited() {
    dockRoot.anyAppHovered = false;
    TooltipService.hide();
    if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.menuHovered && dockRoot.dragSourceIndex === -1) {
      dockRoot.hideTimer.restart();
    }
  }

  Rectangle {
    id: dockContainer

    // DDE fashion surface: maskShell rounded rect flush to the screen edge
    // (radiusItem = 5 px when compositing is on), no border, no shadow.
    // dock.backgroundOpacity multiplies the token alpha on top of
    // ui.panelBackgroundOpacity — the dock knob only detunes the dock.
    color: Qt.rgba(Color.maskShell.r, Color.maskShell.g, Color.maskShell.b, Color.maskShell.a * Settings.data.dock.backgroundOpacity)
    radius: Style.radiusItem

    readonly property real contentLength: Math.min(dockLayout.implicitLength + Style.margin2XS, dockRoot.maxLength)
    width: isVertical ? dockRoot.itemThickness : contentLength
    height: isVertical ? contentLength : dockRoot.itemThickness

    // Publish the surface length so the mini launcher can align with the
    // dock's start edge (DESIGN §3.4.2); the dock is centred on its long axis.
    readonly property string _screenName: dockRoot.modelData ? dockRoot.modelData.name : ""
    function publishLength() {
      BarService.setDockLength(_screenName, isVertical ? height : width);
    }
    onWidthChanged: publishLength()
    onHeightChanged: publishLength()
    Component.onCompleted: publishLength()

    anchors.horizontalCenter: isVertical ? undefined : parent.horizontalCenter
    anchors.verticalCenter: isVertical ? parent.verticalCenter : undefined
    anchors.bottom: dockRoot.dockPosition === "bottom" ? parent.bottom : undefined
    anchors.top: dockRoot.dockPosition === "top" ? parent.top : undefined
    anchors.left: dockRoot.dockPosition === "left" ? parent.left : undefined
    anchors.right: dockRoot.dockPosition === "right" ? parent.right : undefined

    clip: true

    // Empty-dock-area interactions: hover keeps the dock alive, right-click
    // opens the light dock settings menu (DESIGN §3.1.1).
    MouseArea {
      id: dockBgMouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      z: -1

      onEntered: {
        dockRoot.dockHovered = true;
        if (dockRoot.autoHide) {
          dockRoot.showTimer.stop();
          dockRoot.hideTimer.stop();
          dockRoot.hidden = false;
        }
      }

      onExited: {
        dockRoot.dockHovered = false;
        if (dockRoot.autoHide && !dockRoot.anyAppHovered && !dockRoot.menuHovered && dockRoot.dragSourceIndex === -1) {
          dockRoot.hideTimer.restart();
        }
      }

      onClicked: mouse => {
                   if (mouse.button === Qt.RightButton) {
                     TooltipService.hideImmediately();
                     DockSettingsMenu.openAtItemPoint(dock.screen, dockBgMouseArea, mouse.x, mouse.y);
                     mouse.accepted = true;
                     return;
                   }
                   if (LauncherState.anyOpen) {
                     LauncherState.close(null);
                   }
                   dockRoot.closeAllContextMenus();
                 }
    }

    GridLayout {
      id: dockLayout
      columns: isVertical ? 1 : -1
      rows: isVertical ? -1 : 1
      rowSpacing: itemSpacing
      columnSpacing: itemSpacing
      anchors.centerIn: parent

      readonly property int implicitLength: isVertical ? implicitHeight : implicitWidth

      // ---------------- Content segments ----------------
      // Flat strip: taskbarWidgets.left ++ center ++ dock.plugins — the same
      // lists the taskbar-mode editor writes, so every item (launcher, app
      // strip, indicators) is repositionable across both modes (§3.5.3).
      Repeater {
        model: dock.contentSegments
        delegate: Loader {
          required property var modelData
          required property int index
          readonly property string segKind: modelData.kind
          Layout.alignment: Qt.AlignCenter
          Layout.fillWidth: !isVertical && segKind === "item" && modelData.entry.id === "Spacer"
          Layout.fillHeight: isVertical && segKind === "item" && modelData.entry.id === "Spacer"
          Layout.preferredWidth: implicitWidth
          Layout.preferredHeight: implicitHeight
          sourceComponent: segKind === "plugins" ? pluginRunComp : (modelData.entry.id === "Launcher" ? launcherComp : (modelData.entry.id === "Taskbar" ? taskbarComp : spacerComp))
          onLoaded: {
            if (item.segTag !== undefined)
              item.segTag = modelData._tag;
            if (item.segEntry !== undefined)
              item.segEntry = modelData.entry;
            if (item.segEntries !== undefined)
              item.segEntries = modelData.entries;
          }
        }
      }

    }
  Component {
    id: launcherComp
    // ---------------- Launcher item (always first) ----------------
    Item {
      id: launcherItem

      // The Launcher list entry (taskbarWidgets/plugins) — its keys feed the
      // same merge chain as before: dock.launcher* > entry > registry metadata.
      property var segEntry: ({})
      implicitWidth: isVertical ? dockRoot.itemThickness : appItemLength
      implicitHeight: isVertical ? appItemLength : dockRoot.itemThickness

      readonly property real appItemLength: Math.round(dockRoot.itemLength * shrinkFactor)
      readonly property real appIconContent: Math.round(Math.min(implicitWidth, implicitHeight) * 0.8)
      readonly property string screenName: dock.screen ? dock.screen.name : ""
      readonly property var launcherWidgetSettings: segEntry || {}
      readonly property var launcherMetadata: BarWidgetRegistry.widgetMetadata["Launcher"]
      readonly property string launcherIcon: {
        if (Settings.data.dock.launcherIcon !== undefined && Settings.data.dock.launcherIcon !== "")
          return Settings.data.dock.launcherIcon;
        if (launcherWidgetSettings.icon !== undefined && launcherWidgetSettings.icon !== "")
          return launcherWidgetSettings.icon;
        return (launcherMetadata && launcherMetadata.icon) ? launcherMetadata.icon : "search";
      }
      readonly property string launcherIconColorKey: {
        if (Settings.data.dock.launcherIconColor !== undefined)
          return Settings.data.dock.launcherIconColor;
        if (launcherWidgetSettings.iconColor !== undefined)
          return launcherWidgetSettings.iconColor;
        if (launcherMetadata && launcherMetadata.iconColor !== undefined)
          return launcherMetadata.iconColor;
        return "none";
      }
      readonly property bool launcherUseDistroLogo: {
        if (Settings.data.dock.launcherUseDistroLogo !== undefined)
          return Settings.data.dock.launcherUseDistroLogo;
        if (launcherWidgetSettings.useDistroLogo !== undefined)
          return launcherWidgetSettings.useDistroLogo;
        if (launcherMetadata && launcherMetadata.useDistroLogo !== undefined)
          return launcherMetadata.useDistroLogo;
        return false;
      }
      // DDE launcher tile: the one launcher-icon source (DESIGN §1.9), shared
      // with the efficient taskbar plugin and the status-bar widget
      // (gxde-dock/frame/item/launcheritem.cpp:56-60)
      readonly property string themedLauncherIcon: ThemeIcons.launcherIconPath()

      Item {
        id: launcherIconContainer
        // dock.launcherIconSize is px here too; 0 = follow dock.iconSize.
        width: Settings.data.dock.launcherIconSize > 0 ? Settings.data.dock.launcherIconSize : launcherItem.appIconContent
        height: width
        anchors.centerIn: parent

        // Priority (DESIGN §1.9 "用户在设置里指定的自定义图标优先"):
        // distro logo > user-picked glyph > themed deepin-launcher path.
        // launcherIconPath() always resolves (bundled fallback), so the
        // themed image must yield when a glyph is configured — previously
        // it never did and the icon picker wrote a dead key.
        IconImage {
          anchors.fill: parent
          source: launcherItem.themedLauncherIcon
          visible: launcherItem.themedLauncherIcon !== "" && !launcherItem.launcherUseDistroLogo && launcherItem.launcherIcon === ""
          smooth: true
          asynchronous: true
        }

        NIcon {
          anchors.centerIn: parent
          icon: launcherItem.launcherIcon
          pointSize: launcherIconContainer.width * 0.7
          color: Color.resolveColorKey(launcherItem.launcherIconColorKey)
          visible: !launcherItem.launcherUseDistroLogo && launcherItem.launcherIcon !== ""
        }

        IconImage {
          anchors.fill: parent
          source: launcherItem.launcherUseDistroLogo ? HostService.osLogo : ""
          visible: source !== "" && launcherItem.launcherUseDistroLogo
          smooth: true
          asynchronous: true
          layer.enabled: visible
          layer.effect: ShaderEffect {
            property color targetColor: Color.resolveColorKey(launcherItem.launcherIconColorKey)
            property real colorizeMode: 2.0

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
          }
        }

        // DDE hover: brighten the icon, no hover background (DESIGN §3.1.2).
        // layer.enabled must never toggle from hover-driven bindings: Qt
        // reparents the layer's effectSource/effect into our parent item and
        // deletes them synchronously on disable — a use-after-free for any
        // in-flight hover delivery snapshot.
        layer.enabled: true
        layer.effect: MultiEffect {
          brightness: launcherMouseArea.containsMouse ? 0.15 : 0.0
        }
      }

      MouseArea {
        id: launcherMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onEntered: {
          itemEntered();
          TooltipService.show(launcherItem, I18n.tr("actions.open-launcher"), tooltipDirection, Style.tooltipDelayDock);
        }

        onExited: itemExited()

        onClicked: mouse => {
                     const targetScreen = dock.screen || null;
                     if (!targetScreen)
                     return;

                     if (mouse.button === Qt.RightButton) {
                       if (dockRoot.currentContextMenu === launcherContextMenu && launcherContextMenu.shown) {
                         dockRoot.closeAllContextMenus();
                         return;
                       }
                       dockRoot.closeAllContextMenus();
                       TooltipService.hideImmediately();
                       launcherContextMenu.show(launcherItem, null, targetScreen);
                       return;
                     }

                     if (mouse.button === Qt.LeftButton || mouse.button === Qt.MiddleButton) {
                       dockRoot.closeAllContextMenus();
                       PanelService.toggleLauncher(targetScreen);
                     }
                   }
      }

      DockMenu {
        id: launcherContextMenu
        dockPosition: dockRoot.dockPosition
        menuMode: "launcher"

        onHoveredChanged: {
          if (dockRoot.currentContextMenu === launcherContextMenu && launcherContextMenu.shown) {
            dockRoot.menuHovered = hovered;
          } else {
            dockRoot.menuHovered = false;
          }
        }

        Connections {
          target: launcherContextMenu
          function onRequestClose() {
            dockRoot.currentContextMenu = null;
            launcherContextMenu.hide();
            dockRoot.menuHovered = false;
            dockRoot.anyAppHovered = false;
          }
        }

        onVisibleChanged: {
          if (visible) {
            dockRoot.currentContextMenu = launcherContextMenu;
          } else if (dockRoot.currentContextMenu === launcherContextMenu) {
            dockRoot.currentContextMenu = null;
            dockRoot.menuHovered = false;
            if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.anyAppHovered && !dockRoot.menuHovered) {
              dockRoot.hideTimer.restart();
            }
          }
        }
      }
    }
  }

  Component {
    id: taskbarComp
    // The taskbar segment: one slot in the dock sequence holding the whole
    // app strip. Sizing is implicit — the Loader reads it for the segment cell.
    Item {
      implicitWidth: isVertical ? dockRoot.itemThickness : appStrip.implicitWidth
      implicitHeight: isVertical ? appStrip.implicitHeight : dockRoot.itemThickness

      GridLayout {
        id: appStrip
        rows: isVertical ? -1 : 1
        columns: isVertical ? 1 : -1
        rowSpacing: itemSpacing
        columnSpacing: itemSpacing

        // ---------------- App items ----------------
        Repeater {
          // Model is the keyed row list (dockRows): rows carry a string rkey,
          // not the entry — boxing an entry into QVariantMap would turn its
          // Toplevel refs into raw pointers that lose QPointer tracking
          // (CODING_STANDARDS "QML 规则"). The delegate resolves the live JS
          // entry itself; dying rows collapse in place before removal.
          model: dockRoot.dockRows

          delegate: Item {
            id: appButton
            readonly property var entry: dockRoot._entryForRow(model.rkey)
            readonly property real appItemLength: Math.round(dockRoot.itemLength * shrinkFactor)
            readonly property real appIconContent: Math.round(Math.min(appItemLength, dockRoot.itemThickness) * 0.8)

            // Collapse/grow lifecycle: rows enter at 0 and dying rows collapse
            // back to 0 on the long axis before the model drops them.
            readonly property bool collapsing: model.dying === true
            property bool _entered: false
            Component.onCompleted: _entered = true
            readonly property bool _shrunk: collapsing || !_entered
            readonly property real longLen_: isVertical ? Layout.preferredHeight : Layout.preferredWidth
            onLongLen_Changed: {
              if (collapsing && longLen_ <= 0)
                dockRoot._dropDockRow(model.rkey);
            }

            opacity: _shrunk ? 0 : 1
            Behavior on opacity {
              NumberAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
              }
            }

            Layout.preferredWidth: isVertical ? dockRoot.itemThickness : (appButton._shrunk ? 0 : appItemLength)
            Layout.preferredHeight: isVertical ? (appButton._shrunk ? 0 : appItemLength) : dockRoot.itemThickness
            Layout.alignment: Qt.AlignCenter

            Behavior on Layout.preferredWidth {
              NumberAnimation {
                duration: appButton.collapsing ? Style.animationFast : Style.animationNormal
                easing.type: appButton.collapsing ? Easing.InCubic : Easing.InOutCubic
              }
            }
            Behavior on Layout.preferredHeight {
              NumberAnimation {
                duration: appButton.collapsing ? Style.animationFast : Style.animationNormal
                easing.type: appButton.collapsing ? Easing.InCubic : Easing.InOutCubic
              }
            }

            property var toplevels: dock.getValidToplevels(entry)
            property bool isActive: ToplevelManager && ToplevelManager.activeToplevel && toplevels.includes(ToplevelManager.activeToplevel)
            property bool hovered: appMouseArea.containsMouse
            property string appId: entry ? entry.appId : ""
            property int groupedCount: toplevels.length
            property bool isUrgentApp: dock.isUrgent(entry)
            property string appTitle: {
              if (!entry)
                return "";
              const primaryToplevel = dock.getPrimaryToplevel(entry);
              if (primaryToplevel) {
                const toplevelTitle = primaryToplevel.title || "";
                if (!toplevelTitle || toplevelTitle === "Loading..." || toplevelTitle.trim() === "") {
                  return dockRoot.getAppNameFromDesktopEntry(entry.appId) || entry.appId;
                }
                return toplevelTitle;
              }
              return entry.title || entry.appId || "";
            }
            property bool isRunning: toplevels.length > 0

            // Live-list index for drag-and-drop (dying rows hold extra slots)
            property int modelIndex: dockRoot._liveIndexOf(model.rkey)
            objectName: "dockAppButton"

            // Attention: damped swing — ±8° rotation with 18px lift, one
            // 1200ms Linear cycle, re-armed every ~2.2s while urgent
            // (DESIGN §3.1.2; gxde-dock appitem.cpp checkAttentionEffect,
            // appswingeffectbuilder.h Frames table).
            onIsUrgentAppChanged: {
              if (isUrgentApp) {
                if (Style.motionSwing > 0)
                  swingAnim.restart();
                swingRepeatTimer.restart();
              } else {
                swingRepeatTimer.stop();
                swingAnim.stop();
                iconContainer.swingPhase = 0;
              }
            }

            Timer {
              id: swingRepeatTimer
              interval: Style.motionSwing + 1000
              repeat: true
              onTriggered: {
                if (appButton.isUrgentApp)
                  swingAnim.restart();
              }
            }

            NumberAnimation {
              id: swingAnim
              target: iconContainer
              property: "swingPhase"
              from: 0
              to: 1
              duration: Style.motionSwing
              easing.type: Easing.Linear
              onStopped: iconContainer.swingPhase = 0
            }

            DropArea {
              anchors.fill: parent
              keys: ["dock-app"]
              onEntered: function (drag) {
                if (drag.source && drag.source.objectName === "dockAppButton") {
                  dockRoot.dragTargetIndex = appButton.modelIndex;
                }
              }
              onExited: function () {
                if (dockRoot.dragTargetIndex === appButton.modelIndex) {
                  dockRoot.dragTargetIndex = -1;
                }
              }
              onDropped: function (drop) {
                dockRoot.dragSourceIndex = -1;
                dockRoot.dragTargetIndex = -1;
                if (drop.source && drop.source.objectName === "dockAppButton" && drop.source !== appButton) {
                  dockRoot.reorderApps(drop.source.modelIndex, appButton.modelIndex);
                }
              }
            }

            // Listen for the toplevel being closed
            Connections {
              target: entry?.toplevel ?? null
              function onClosed() {
                Qt.callLater(dockRoot.updateDockApps);
              }
            }

            // Draggable container for the icon
            Item {
              id: iconContainer
              width: appButton.appIconContent
              height: appButton.appIconContent
              transformOrigin: Item.Center

              // Swing phase drives a damped ~2.75-cycle ±8° oscillation and a
              // constant 18px lift while running (appswingeffectbuilder.h:
              // rotation frames decay 8→0, translation held at -18). At rest
              // the formula would read 8° — gate it on the animation so idle
              // icons sit level.
              property real swingPhase: 0
              rotation: swingAnim.running ? 8 * Math.sin(swingPhase * 2.75 * 2 * Math.PI + Math.PI / 2) * (1 - swingPhase) : 0

              // When dragging, remove anchors so MouseArea can position it
              anchors.centerIn: dragging ? undefined : parent
              anchors.verticalCenterOffset: swingPhase !== 0 ? -Math.round(18 * Style.uiScaleRatio) : 0

              property bool dragging: appMouseArea.drag.active
              onDraggingChanged: {
                if (dragging) {
                  dockRoot.dragSourceIndex = appButton.modelIndex;
                } else {
                  // Reset if not handled by drop (e.g. dropped outside)
                  Qt.callLater(() => {
                                 if (!appMouseArea.drag.active && dockRoot.dragSourceIndex === appButton.modelIndex) {
                                   dockRoot.dragSourceIndex = -1;
                                   dockRoot.dragTargetIndex = -1;
                                 }
                               });
                }
              }

              Drag.active: dragging
              Drag.source: appButton
              Drag.hotSpot.x: width / 2
              Drag.hotSpot.y: height / 2
              Drag.keys: ["dock-app"]

              z: (dockRoot.dragSourceIndex === appButton.modelIndex) ? 1000 : ((dragging ? 1000 : 0))

              // Visual shifting logic — modelIndex is the position in the live
              // app list (dying rows hold extra slots past it)
              readonly property bool isDragged: dockRoot.dragSourceIndex === appButton.modelIndex
              property real shiftOffset: 0

              Binding on shiftOffset {
                value: {
                  if (dockRoot.dragSourceIndex !== -1 && dockRoot.dragTargetIndex !== -1 && !iconContainer.isDragged) {
                    var step = appButton.appItemLength + itemSpacing;
                    if (dockRoot.dragSourceIndex < dockRoot.dragTargetIndex) {
                      // Dragging Forward: Items between source and target shift Backward
                      if (appButton.modelIndex > dockRoot.dragSourceIndex && appButton.modelIndex <= dockRoot.dragTargetIndex) {
                        return -step;
                      }
                    } else if (dockRoot.dragSourceIndex > dockRoot.dragTargetIndex) {
                      // Dragging Backward: Items between target and source shift Forward
                      if (appButton.modelIndex >= dockRoot.dragTargetIndex && appButton.modelIndex < dockRoot.dragSourceIndex) {
                        return step;
                      }
                    }
                  }
                  return 0;
                }
              }

              transform: Translate {
                x: !dockRoot.isVertical ? iconContainer.shiftOffset : 0
                y: dockRoot.isVertical ? iconContainer.shiftOffset : 0

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

              IconImage {
                id: appIcon
                anchors.fill: parent
                source: {
                  dockRoot.iconRevision; // Force re-evaluation when revision changes
                  return dock.getAppIcon(entry);
                }
                visible: source.toString() !== ""
                smooth: true
                asynchronous: true

                // Dim pinned apps that aren't running
                opacity: appButton.isRunning ? 1.0 : (Settings.data.dock.deadOpacity)

                // Apply dock-specific colorization shader only to non-focused apps
                layer.enabled: !appButton.isActive && (Settings.data.dock.colorizeIcons)
                layer.smooth: true
                layer.effect: ShaderEffect {
                  property color targetColor: Color.onShell
                  property real colorizeMode: 0.0 // Dock mode (grayscale)

                  fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
                }

                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutCubic
                  }
                }
              }

              // Fall back if no icon
              NIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                icon: "question-mark"
                pointSize: appButton.appIconContent * 0.7
                color: appButton.isActive ? Color.accent : Color.onShellSecondary
                opacity: appButton.isRunning ? 1.0 : 0.6
              }

              // DDE hover: brighten the icon, no hover background (DESIGN §3.1.2).
              // Keep layer.enabled constant — see launcherIconContainer above.
              layer.enabled: true
              layer.effect: MultiEffect {
                brightness: appButton.hovered && !iconContainer.dragging ? 0.15 : 0.0
              }
            }

            // Context menu popup (dark arrowed menu, arrow tip 2 px from item)
            DockMenu {
              id: contextMenu
              dockPosition: dockRoot.dockPosition
              onHoveredChanged: {
                if (dockRoot.currentContextMenu === contextMenu && contextMenu.shown) {
                  dockRoot.menuHovered = hovered;
                } else {
                  dockRoot.menuHovered = false;
                }
              }

              Connections {
                target: contextMenu
                function onRequestClose() {
                  dockRoot.currentContextMenu = null;
                  contextMenu.hide();
                  dockRoot.menuHovered = false;
                  dockRoot.anyAppHovered = false;
                }
              }
              onAppClosed: dockRoot.updateDockApps
              onVisibleChanged: {
                if (visible) {
                  dockRoot.currentContextMenu = contextMenu;
                } else if (dockRoot.currentContextMenu === contextMenu) {
                  dockRoot.currentContextMenu = null;
                  dockRoot.menuHovered = false;
                  if (dockRoot.autoHide && !dockRoot.dockHovered && !dockRoot.anyAppHovered && !dockRoot.menuHovered) {
                    dockRoot.hideTimer.restart();
                  }
                }
              }
            }

            MouseArea {
              id: appMouseArea
              objectName: "appMouseArea"
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

              // The icon square is centered: the app context menu is only
              // reachable inside it (DESIGN §3.1.1 right-click zones)
              function insideIconSquare(mx, my) {
                var s = appButton.appIconContent;
                var cx = (width - s) / 2;
                var cy = (height - s) / 2;
                return mx >= cx && mx <= cx + s && my >= cy && my <= cy + s;
              }

              // Only allow left-click dragging via axis control
              drag.target: iconContainer
              drag.axis: (pressedButtons & Qt.LeftButton) ? (dockRoot.isVertical ? Drag.YAxis : Drag.XAxis) : Drag.None

              onPressed: {
                var p1 = appButton.mapFromItem(dockContainer, 0, 0);
                var p2 = appButton.mapFromItem(dockContainer, dockContainer.width, dockContainer.height);
                drag.minimumX = p1.x;
                drag.maximumX = p2.x - iconContainer.width;
                drag.minimumY = p1.y;
                drag.maximumY = p2.y - iconContainer.height;
              }

              onReleased: {
                if (iconContainer.Drag.active) {
                  iconContainer.Drag.drop();
                }
              }

              onEntered: {
                dock.itemEntered();
                const appName = appButton.appTitle || appButton.appId || "Unknown";
                const tooltipText = appName.length > 40 ? appName.substring(0, 37) + "..." : appName;
                if (!contextMenu.shown) {
                  TooltipService.show(appButton, tooltipText, tooltipDirection, Style.tooltipDelayDock);
                }
              }

              onExited: {
                dock.itemExited();
                if (!dockRoot.currentContextMenu || !dockRoot.currentContextMenu.shown) {
                  dockRoot.menuHovered = false;
                }
              }

              onClicked: mouse => {
                           const targetScreen = dock.screen || null;
                           if (mouse.button === Qt.RightButton) {
                             if (!insideIconSquare(mouse.x, mouse.y)) {
                               // Right-click outside the icon square -> dock settings menu
                               TooltipService.hideImmediately();
                               dockRoot.closeAllContextMenus();
                               DockSettingsMenu.openAtItemPoint(targetScreen, appMouseArea, mouse.x, mouse.y);
                               return;
                             }
                             if (dockRoot.currentContextMenu === contextMenu && contextMenu.shown) {
                               dockRoot.closeAllContextMenus();
                               return;
                             }
                             dockRoot.closeAllContextMenus();
                             TooltipService.hideImmediately();
                             contextMenu.show(appButton, entry, targetScreen);
                             return;
                           }

                           if (LauncherState.anyOpen) {
                             LauncherState.close(null);
                           }
                           dockRoot.closeAllContextMenus();

                           const runningToplevels = dock.getValidToplevels(entry);
                           const primaryToplevel = dock.getPrimaryToplevel(entry);

                           if (mouse.button === Qt.MiddleButton) {
                             if (primaryToplevel && primaryToplevel.close) {
                               primaryToplevel.close();
                               Qt.callLater(dockRoot.updateDockApps);
                             }
                           } else if (mouse.button === Qt.LeftButton) {
                             if (runningToplevels.length === 0) {
                               dock.launchAppById(entry?.appId);
                               return;
                             }

                             if (!Settings.data.dock.groupApps || runningToplevels.length <= 1) {
                               if (primaryToplevel && primaryToplevel.activate) {
                                 primaryToplevel.activate();
                               }
                               return;
                             }

                             const clickAction = Settings.data.dock.groupClickAction || "cycle";
                             if (clickAction === "list") {
                               TooltipService.hideImmediately();
                               contextMenu.show(appButton, entry, targetScreen, "list");
                             } else {
                               const appKey = entry?.appId || "";
                               const state = dockRoot.groupCycleIndices || {};
                               const nextIndex = (state[appKey] || 0) % runningToplevels.length;
                               const nextToplevel = runningToplevels[nextIndex];
                               if (nextToplevel && nextToplevel.activate) {
                                 nextToplevel.activate();
                               }
                               state[appKey] = (nextIndex + 1) % runningToplevels.length;
                               dockRoot.groupCycleIndices = Object.assign({}, state);
                             }
                           }
                         }
            }

            // DDE running indicator (DESIGN §3.1.2): 20x2 bar (2x20 vertical) on
            // the screen-edge side, 2 px from the item edge; running = white
            // x0.25, active = accent with horizontally fading ends,
            // attention = Color.attention.
            Rectangle {
              visible: appButton.isRunning
              width: isVertical ? 2 : Math.min(20, Math.max(4, appButton.appIconContent * 0.5))
              height: isVertical ? Math.min(20, Math.max(4, appButton.appIconContent * 0.5)) : 2
              color: "transparent"
              radius: 1

              // Position on the screen-edge side, 2 px from that edge
              anchors.bottom: !isVertical && dockRoot.dockPosition === "bottom" ? parent.bottom : undefined
              anchors.top: !isVertical && dockRoot.dockPosition === "top" ? parent.top : undefined
              anchors.left: isVertical && dockRoot.dockPosition === "left" ? parent.left : undefined
              anchors.right: isVertical && dockRoot.dockPosition === "right" ? parent.right : undefined
              anchors.horizontalCenter: isVertical ? undefined : parent.horizontalCenter
              anchors.verticalCenter: isVertical ? parent.verticalCenter : undefined
              anchors.bottomMargin: !isVertical && dockRoot.dockPosition === "bottom" ? 2 : 0
              anchors.topMargin: !isVertical && dockRoot.dockPosition === "top" ? 2 : 0
              anchors.leftMargin: isVertical && dockRoot.dockPosition === "left" ? 2 : 0
              anchors.rightMargin: isVertical && dockRoot.dockPosition === "right" ? 2 : 0

              Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: !appButton.isActive
                color: appButton.isUrgentApp ? Color.attention : Color.overlay("indicator")
              }

              // Active window: accent bar with fading ends (appitem.cpp:320-358)
              Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: appButton.isActive && !appButton.isUrgentApp
                gradient: Gradient {
                  orientation: isVertical ? Gradient.Vertical : Gradient.Horizontal
                  GradientStop {
                    position: 0.0
                    color: "transparent"
                  }
                  GradientStop {
                    position: 0.3
                    color: Color.accent
                  }
                  GradientStop {
                    position: 0.7
                    color: Color.accent
                  }
                  GradientStop {
                    position: 1.0
                    color: "transparent"
                  }
                }
              }
              Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: appButton.isActive && appButton.isUrgentApp
                gradient: Gradient {
                  orientation: isVertical ? Gradient.Vertical : Gradient.Horizontal
                  GradientStop {
                    position: 0.0
                    color: "transparent"
                  }
                  GradientStop {
                    position: 0.3
                    color: Color.attention
                  }
                  GradientStop {
                    position: 0.7
                    color: Color.attention
                  }
                  GradientStop {
                    position: 1.0
                    color: "transparent"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: spacerComp
    // A fixed gap — the fashion dock hugs its content, so fillWidth would be
    // a no-op; the stretch semantics stay on the efficient bar.
    Item {
      implicitWidth: Style.marginL
      implicitHeight: Style.marginL
    }
  }

  Component {
    id: pluginRunComp
    // One contiguous plugin run = the 6 px slit + plugin tile. Multiple runs
    // are possible once entries interleave with Launcher/Taskbar segments.
    Item {
      id: pluginRun
      property var segEntries: []
      property string segTag: ""
      implicitWidth: isVertical ? dockRoot.itemThickness : Style.marginS + pluginArea.implicitWidth
      implicitHeight: isVertical ? Style.marginS + pluginArea.implicitHeight : dockRoot.itemThickness

      function reportLen() {
        dock._noteSegLen(segTag, isVertical ? implicitHeight : implicitWidth);
      }
      onImplicitWidthChanged: reportLen()
      onImplicitHeightChanged: reportLen()
      Component.onDestruction: dock._noteSegLen(segTag, 0)

      // The slit that separated the app strip from the plugin area now leads
      // each plugin run wherever the user places it (DESIGN §3.1.1).
      Item {
        id: slitItem
        width: isVertical ? 0 : Style.marginS - itemSpacing
        height: isVertical ? Style.marginS - itemSpacing : 0
      }

  Item {
          id: pluginArea

          visible: pluginRun.segEntries.length > 0
          // implicit size = real item size in the layout cell (a bare Item
          // reports 0 and the fused pill below would collapse with it)
          implicitWidth: isVertical ? dockRoot.itemThickness : pluginGrid.implicitWidth + fusedPad
          implicitHeight: isVertical ? pluginGrid.implicitHeight + fusedPad : dockRoot.itemThickness

          readonly property real fusedPad: Settings.data.dock.fusedPlugins ? Style.marginXS * 2 : 0

          Rectangle {
            visible: Settings.data.dock.fusedPlugins
            anchors.centerIn: parent
            width: isVertical ? Style.dockPluginTileSize + Style.marginXS * 2 : pluginGrid.implicitWidth + parent.fusedPad
            height: isVertical ? pluginGrid.implicitHeight + parent.fusedPad : Style.dockPluginTileSize + Style.marginXS * 2
            radius: Style.radiusL
            color: Color.overlay("subtle")
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth
          }

          GridLayout {
            id: pluginGrid
            anchors.centerIn: parent
            rows: isVertical ? pluginRun.segEntries.length : 1
            columns: isVertical ? 1 : pluginRun.segEntries.length
            rowSpacing: itemSpacing
            columnSpacing: itemSpacing

            Repeater {
              model: pluginRun.segEntries
              delegate: BarWidgetLoader {
                required property var modelData
                required property int index

                widgetId: modelData.id || ""
                widgetScreen: dock.screen
                dockPresentation: "fashion"
                widgetProps: ({
                                "widgetId": modelData.id,
                                "section": "dock",
                                "sectionWidgetIndex": index,
                                "sectionWidgetsCount": pluginRun.segEntries.length,
                                "dockPresentation": "fashion",
                                // The widget's own per-instance settings object lives
                                // in its dock.plugins entry (there is no bar section
                                // named "dock" for widgets to look up)
                                "widgetSettings": modelData
                              })
                    }
            }
          }
        }
    }
  }
  }
}
