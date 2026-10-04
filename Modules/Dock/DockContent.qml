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

  // Legacy attached-panel insets (StaticDockPanel assigns these); they are
  // inert in fashion mode but kept so the lazy panel stays loadable
  property real extraTop: 0
  property real extraBottom: 0
  property real extraLeft: 0
  property real extraRight: 0
  // Dock.qml passes the ShellScreen as modelData; the legacy StaticDockPanel
  // exposes it as `screen` instead
  readonly property var screen: dockRoot ? (dockRoot.modelData || dockRoot.screen || null) : null
  readonly property bool isVertical: dockRoot.isVertical
  readonly property string tooltipDirection: dockRoot.dockPosition === "left" ? "right" : (dockRoot.dockPosition === "right" ? "left" : (dockRoot.dockPosition === "top" ? "bottom" : "top"))
  readonly property int itemSpacing: Style.marginXXS

  // Plugin entries that are structural or meaningless in fashion mode
  readonly property var pluginList: {
    var out = [];
    var plugins = Settings.data.dock.plugins || [];
    for (var i = 0; i < plugins.length; i++) {
      var p = plugins[i];
      if (!p || !p.id)
        continue;
      // Taskbar/ShowDesktop/Spacer are structural; Launcher is built in;
      // Workspace is hidden in fashion mode (DESIGN §3.1.1)
      if (p.id === "Taskbar" || p.id === "ShowDesktop" || p.id === "Spacer" || p.id === "Launcher" || p.id === "Workspace")
        continue;
      if (!BarWidgetRegistry.hasWidget(p.id))
        continue;
      out.push(p);
    }
    return out;
  }

  // Proportional shrink when the dock would exceed maxLength
  // (gxde-dock mainpanel.cpp:623-698). Plugin area keeps its natural length;
  // app items absorb the deficit.
  readonly property real shrinkFactor: {
    var appCount = dockRoot.dockApps.length + 1; // + launcher
    var pluginLen = pluginAreaLength();
    var gap = pluginList.length > 0 ? Style.marginS + itemSpacing : 0;
    var needed = appCount * (dockRoot.itemLength + itemSpacing) + gap + pluginLen;
    if (needed <= dockRoot.maxLength)
      return 1;
    var availPerApp = (dockRoot.maxLength - pluginLen - gap) / Math.max(1, appCount) - itemSpacing;
    return Math.max(0.4, availPerApp / dockRoot.itemLength);
  }

  function pluginAreaLength() {
    // Tray expands dynamically; each other plugin occupies a square item
    return pluginList.length * (dockRoot.itemThickness + itemSpacing);
  }

  function getAppIcon(appData): string {
    if (!appData || !appData.appId)
      return "";
    return ThemeIcons.iconForAppId(appData.appId?.toLowerCase());
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

    if (Settings.data.appLauncher.customLaunchPrefixEnabled && Settings.data.appLauncher.customLaunchPrefix.trim() !== "") {
      const prefix = Settings.data.appLauncher.customLaunchPrefix.trim().split(" ");

      if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
        const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
        const command = prefix.concat(terminal.concat(app.command));
        Quickshell.execDetached(command);
      } else {
        const command = prefix.concat(app.command);
        Quickshell.execDetached(command);
      }
    } else {
      if (app.runInTerminal && Settings.data.appLauncher.terminalCommand.trim() !== "") {
        Logger.d("Dock", "Executing terminal app manually: " + app.name);
        const terminal = Settings.data.appLauncher.terminalCommand.trim().split(" ");
        const command = terminal.concat(app.command);
        CompositorService.spawn(command);
      } else if (app.command && app.command.length > 0) {
        CompositorService.spawn(app.command);
      } else if (app.execute) {
        app.execute();
      } else {
        Logger.w("Dock", `Could not launch: ${app.name}. No valid launch method.`);
      }
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
    color: Color.maskShell
    radius: Style.radiusItem

    readonly property real contentLength: Math.min(dockLayout.implicitLength + Style.margin2XS, dockRoot.maxLength)
    width: isVertical ? dockRoot.itemThickness : contentLength
    height: isVertical ? contentLength : dockRoot.itemThickness

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

      // ---------------- Launcher item (always first) ----------------
      Item {
        id: launcherItem
        Layout.preferredWidth: isVertical ? dockRoot.itemThickness : appItemLength
        Layout.preferredHeight: isVertical ? appItemLength : dockRoot.itemThickness
        Layout.alignment: Qt.AlignCenter

        readonly property real appItemLength: Math.round(dockRoot.itemLength * shrinkFactor)
        readonly property real appIconContent: Math.round(Math.min(Layout.preferredWidth, Layout.preferredHeight) * 0.8)
        readonly property string screenName: dock.screen ? dock.screen.name : ""
        readonly property var launcherWidgetSettings: {
          const widgetsBySection = screenName ? Settings.getBarWidgetsForScreen(screenName) : Settings.data.bar.widgets;
          if (!widgetsBySection)
            return {};
          const sections = ["left", "center", "right"];
          for (let i = 0; i < sections.length; i++) {
            const sectionWidgets = widgetsBySection[sections[i]] || [];
            for (let j = 0; j < sectionWidgets.length; j++) {
              const widget = sectionWidgets[j];
              if (widget && widget.id === "Launcher")
                return widget;
            }
          }
          return {};
        }
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
        // DDE launcher tile: prefer the deepin-launcher themed icon
        readonly property string themedLauncherIcon: ThemeIcons.fashionForAny(["deepin-launcher", "start-here", "deepin-toggle-desktop"])

        Item {
          id: launcherIconContainer
          width: launcherItem.appIconContent
          height: width
          anchors.centerIn: parent

          IconImage {
            anchors.fill: parent
            source: launcherItem.themedLauncherIcon
            visible: launcherItem.themedLauncherIcon !== "" && !launcherItem.launcherUseDistroLogo
            smooth: true
            asynchronous: true
          }

          NIcon {
            anchors.centerIn: parent
            icon: launcherItem.launcherIcon
            pointSize: launcherItem.appIconContent * 0.7
            color: Color.resolveColorKey(launcherItem.launcherIconColorKey)
            visible: launcherItem.themedLauncherIcon === "" && !launcherItem.launcherUseDistroLogo
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

          // DDE hover: brighten the icon, no hover background (DESIGN §3.1.2)
          layer.enabled: launcherMouseArea.containsMouse
          layer.effect: MultiEffect {
            brightness: 0.15
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
                         if (dockRoot.currentContextMenu === launcherContextMenu && launcherContextMenu.visible) {
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
            if (dockRoot.currentContextMenu === launcherContextMenu && launcherContextMenu.visible) {
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

      // ---------------- App items ----------------
      Repeater {
        model: dockRoot.dockApps

        delegate: Item {
          id: appButton
          readonly property real appItemLength: Math.round(dockRoot.itemLength * shrinkFactor)
          readonly property real appIconContent: Math.round(Math.min(appItemLength, dockRoot.itemThickness) * 0.8)
          Layout.preferredWidth: isVertical ? dockRoot.itemThickness : appItemLength
          Layout.preferredHeight: isVertical ? appItemLength : dockRoot.itemThickness
          Layout.alignment: Qt.AlignCenter

          property var toplevels: dock.getValidToplevels(modelData)
          property bool isActive: ToplevelManager && ToplevelManager.activeToplevel && toplevels.includes(ToplevelManager.activeToplevel)
          property bool hovered: appMouseArea.containsMouse
          property string appId: modelData ? modelData.appId : ""
          property int groupedCount: toplevels.length
          property bool isUrgentApp: dock.isUrgent(modelData)
          property string appTitle: {
            if (!modelData)
              return "";
            const primaryToplevel = dock.getPrimaryToplevel(modelData);
            if (primaryToplevel) {
              const toplevelTitle = primaryToplevel.title || "";
              if (!toplevelTitle || toplevelTitle === "Loading..." || toplevelTitle.trim() === "") {
                return dockRoot.getAppNameFromDesktopEntry(modelData.appId) || modelData.appId;
              }
              return toplevelTitle;
            }
            return modelData.title || modelData.appId || "";
          }
          property bool isRunning: toplevels.length > 0

          // Store index for drag-and-drop
          property int modelIndex: index
          objectName: "dockAppButton"

          // Attention: short swing on the icon + attention-colored indicator
          // (DESIGN §3.1.2; gxde-dock appitem swing effect)
          onIsUrgentAppChanged: {
            if (isUrgentApp)
              swingAnim.restart();
          }

          SequentialAnimation {
            id: swingAnim
            running: false
            NumberAnimation {
              target: iconContainer
              property: "rotation"
              from: 0
              to: 10
              duration: 100
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              target: iconContainer
              property: "rotation"
              to: -10
              duration: 160
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              target: iconContainer
              property: "rotation"
              to: 8
              duration: 140
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              target: iconContainer
              property: "rotation"
              to: -8
              duration: 140
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              target: iconContainer
              property: "rotation"
              to: 0
              duration: 100
              easing.type: Easing.InOutQuad
            }
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
            target: modelData?.toplevel
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

            // When dragging, remove anchors so MouseArea can position it
            anchors.centerIn: dragging ? undefined : parent

            property bool dragging: appMouseArea.drag.active
            onDraggingChanged: {
              if (dragging) {
                dockRoot.dragSourceIndex = index;
              } else {
                // Reset if not handled by drop (e.g. dropped outside)
                Qt.callLater(() => {
                               if (!appMouseArea.drag.active && dockRoot.dragSourceIndex === index) {
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

            z: (dockRoot.dragSourceIndex === index) ? 1000 : ((dragging ? 1000 : 0))

            // Visual shifting logic
            readonly property bool isDragged: dockRoot.dragSourceIndex === index
            property real shiftOffset: 0

            Binding on shiftOffset {
              value: {
                if (dockRoot.dragSourceIndex !== -1 && dockRoot.dragTargetIndex !== -1 && !iconContainer.isDragged) {
                  var step = appButton.appItemLength + itemSpacing;
                  if (dockRoot.dragSourceIndex < dockRoot.dragTargetIndex) {
                    // Dragging Forward: Items between source and target shift Backward
                    if (index > dockRoot.dragSourceIndex && index <= dockRoot.dragTargetIndex) {
                      return -step;
                    }
                  } else if (dockRoot.dragSourceIndex > dockRoot.dragTargetIndex) {
                    // Dragging Backward: Items between target and source shift Forward
                    if (index >= dockRoot.dragTargetIndex && index < dockRoot.dragSourceIndex) {
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
                  easing.type: Easing.OutQuad
                }
              }
              Behavior on y {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutQuad
                }
              }
            }

            IconImage {
              id: appIcon
              anchors.fill: parent
              source: {
                dockRoot.iconRevision; // Force re-evaluation when revision changes
                return dock.getAppIcon(modelData);
              }
              visible: source.toString() !== ""
              smooth: true
              asynchronous: true

              // Dim pinned apps that aren't running
              opacity: appButton.isRunning ? 1.0 : (Settings.data.dock.deadOpacity ?? 1.0)

              // Apply dock-specific colorization shader only to non-focused apps
              layer.enabled: !appButton.isActive && (Settings.data.dock.colorizeIcons ?? false)
              layer.smooth: true
              layer.effect: ShaderEffect {
                property color targetColor: Color.onShell
                property real colorizeMode: 0.0 // Dock mode (grayscale)

                fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutQuad
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

            // DDE hover: brighten the icon, no hover background (DESIGN §3.1.2)
            layer.enabled: appButton.hovered && !iconContainer.dragging
            layer.effect: MultiEffect {
              brightness: 0.15
            }
          }

          // Context menu popup (dark arrowed menu, arrow tip 2 px from item)
          DockMenu {
            id: contextMenu
            dockPosition: dockRoot.dockPosition
            onHoveredChanged: {
              if (dockRoot.currentContextMenu === contextMenu && contextMenu.visible) {
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
              if (!contextMenu.visible) {
                TooltipService.show(appButton, tooltipText, tooltipDirection, Style.tooltipDelayDock);
              }
            }

            onExited: {
              dock.itemExited();
              if (!dockRoot.currentContextMenu || !dockRoot.currentContextMenu.visible) {
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
                           if (dockRoot.currentContextMenu === contextMenu && contextMenu.visible) {
                             dockRoot.closeAllContextMenus();
                             return;
                           }
                           dockRoot.closeAllContextMenus();
                           TooltipService.hideImmediately();
                           contextMenu.show(appButton, modelData, targetScreen);
                           return;
                         }

                         dockRoot.closeAllContextMenus();

                         const runningToplevels = dock.getValidToplevels(modelData);
                         const primaryToplevel = dock.getPrimaryToplevel(modelData);

                         if (mouse.button === Qt.MiddleButton) {
                           if (primaryToplevel && primaryToplevel.close) {
                             primaryToplevel.close();
                             Qt.callLater(dockRoot.updateDockApps);
                           }
                         } else if (mouse.button === Qt.LeftButton) {
                           if (runningToplevels.length === 0) {
                             dock.launchAppById(modelData?.appId);
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
                             contextMenu.show(appButton, modelData, targetScreen, "list");
                           } else {
                             const appKey = modelData?.appId || "";
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

      // ---------------- 6 px slit before the plugin area ----------------
      Item {
        visible: pluginList.length > 0
        Layout.preferredWidth: isVertical ? 0 : Style.marginS - itemSpacing
        Layout.preferredHeight: isVertical ? Style.marginS - itemSpacing : 0
      }

      // ---------------- Plugin area (dock.plugins, fashion presentation) ----------------
      Repeater {
        model: pluginList
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
                          "sectionWidgetsCount": pluginList.length,
                          "dockPresentation": "fashion",
                          // The widget's own per-instance settings object lives
                          // in its dock.plugins entry (there is no bar section
                          // named "dock" for widgets to look up)
                          "widgetSettings": modelData
                        })
          Layout.alignment: Qt.AlignCenter
        }
      }
    }
  }
}
