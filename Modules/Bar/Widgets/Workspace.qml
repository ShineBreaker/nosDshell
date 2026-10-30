import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../../Commons/WorkspaceQuery.js" as WorkspaceQuery
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  // Lets `debug find <dock|bar>-<screen> workspaceWidget` locate the cell —
  // the dock-plugin context-menu scene right-clicks it to reach settings.
  objectName: "workspaceWidget"

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  // Fashion dock presentation (DESIGN §3.1.4): the widget reuses the bar's
  // pill delegates in a variable-width cell — index/name labels, the grouped
  // app view and direct switching all work there too.
  property string dockPresentation: ""
  readonly property bool fashionMode: dockPresentation === "fashion"

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  // Orientation follows the host surface: dock plugins use the taskbar edge
  // (dock.position + screen override), bar widgets the status bar edge.
  readonly property bool isVertical: {
    const pos = (section === "dock") ? Settings.getTaskbarPositionForScreen(screenName) : barPosition;
    return pos === "left" || pos === "right";
  }
  readonly property bool efficientMode: Settings.data.dock.mode === "efficient"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  // Pill cross-axis base: the bar capsule in bar/efficient, the plugin tile
  // height on the fashion dock so pills sit at the same height as tiles.
  readonly property real _capsule: fashionMode ? Style.dockPluginTileSize : capsuleHeight
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property string labelMode: (widgetSettings.labelMode !== undefined) ? widgetSettings.labelMode : widgetMetadata.labelMode
  readonly property bool hasLabel: (labelMode !== "none")
  readonly property string fontWeight: {
    var fontWeightSetting = (widgetSettings.fontWeight !== undefined) ? widgetSettings.fontWeight : widgetMetadata.fontWeight;

    if (fontWeightSetting === "regular")
      return Style.fontWeightRegular;
    if (fontWeightSetting === "medium")
      return Style.fontWeightMedium;
    if (fontWeightSetting === "semibold")
      return Style.fontWeightSemiBold;
    if (fontWeightSetting === "bold")
      return Style.fontWeightBold;
    return Style.fontWeightBold;
  }
  readonly property bool hideUnoccupied: (widgetSettings.hideUnoccupied !== undefined) ? widgetSettings.hideUnoccupied : widgetMetadata.hideUnoccupied
  readonly property bool followFocusedScreen: (widgetSettings.followFocusedScreen !== undefined) ? widgetSettings.followFocusedScreen : widgetMetadata.followFocusedScreen
  readonly property int characterCount: {
    const count = (widgetSettings.characterCount !== undefined) ? widgetSettings.characterCount : widgetMetadata.characterCount;
    return isVertical ? Math.min(count, 2) : count;
  }

  // Pill size setting (0.5-1.0 range)
  readonly property real pillSize: (widgetSettings.pillSize !== undefined) ? widgetSettings.pillSize : widgetMetadata.pillSize

  // When no label the pills are smaller
  readonly property real baseDimensionRatio: pillSize

  // Grouped mode (show applications) settings — disabled in DDE efficient mode
  readonly property bool showApplications: !efficientMode && ((widgetSettings.showApplications !== undefined) ? widgetSettings.showApplications : widgetMetadata.showApplications)
  readonly property bool showApplicationsHover: (widgetSettings.showApplicationsHover !== undefined) ? widgetSettings.showApplicationsHover : widgetMetadata.showApplicationsHover
  readonly property bool showLabelsOnlyWhenOccupied: (widgetSettings.showLabelsOnlyWhenOccupied !== undefined) ? widgetSettings.showLabelsOnlyWhenOccupied : widgetMetadata.showLabelsOnlyWhenOccupied
  readonly property bool colorizeIcons: (widgetSettings.colorizeIcons !== undefined) ? widgetSettings.colorizeIcons : widgetMetadata.colorizeIcons
  readonly property real unfocusedIconsOpacity: (widgetSettings.unfocusedIconsOpacity !== undefined) ? widgetSettings.unfocusedIconsOpacity : widgetMetadata.unfocusedIconsOpacity
  readonly property real groupedBorderOpacity: (widgetSettings.groupedBorderOpacity !== undefined) ? widgetSettings.groupedBorderOpacity : widgetMetadata.groupedBorderOpacity
  readonly property bool enableScrollWheel: (widgetSettings.enableScrollWheel !== undefined) ? widgetSettings.enableScrollWheel : widgetMetadata.enableScrollWheel
  readonly property bool reverseScroll: Settings.data.general.reverseScroll
  readonly property real iconScale: (widgetSettings.iconScale !== undefined) ? widgetSettings.iconScale : widgetMetadata.iconScale
  readonly property string focusedColor: (widgetSettings.focusedColor !== undefined) ? widgetSettings.focusedColor : widgetMetadata.focusedColor
  readonly property string occupiedColor: (widgetSettings.occupiedColor !== undefined) ? widgetSettings.occupiedColor : widgetMetadata.occupiedColor
  readonly property string emptyColor: (widgetSettings.emptyColor !== undefined) ? widgetSettings.emptyColor : widgetMetadata.emptyColor
  readonly property bool showBadge: (widgetSettings.showBadge !== undefined) ? widgetSettings.showBadge : widgetMetadata.showBadge

  // Only for grouped mode / show apps
  readonly property int baseItemSize: Style.toOdd(_capsule * 0.8)
  readonly property int iconSize: Style.toOdd(baseItemSize * iconScale)
  readonly property real textRatio: 0.50

  // Context menu state for grouped mode - store IDs instead of object references to avoid stale references
  property string selectedWindowId: ""
  property string selectedAppId: ""

  // Helper to get the current window object from ID
  function getSelectedWindow() {
    if (!selectedWindowId)
      return null;
    // Search directly in CompositorService to get the live window object
    for (var i = 0; i < CompositorService.windows.count; i++) {
      var win = CompositorService.windows.get(i);
      // Using loose equality on purpose (==)
      if (win && (win.id == selectedWindowId || win.address == selectedWindowId)) {
        return win;
      }
    }
    return null;
  }

  property bool isDestroying: false

  // Revision counter to force icon re-evaluation
  property int iconRevision: 0
  // Revision counter to force window list re-evaluation (for liveWindows binding in grouped mode)
  property int windowRevision: 0
  // Plain-dict mirror of localWorkspaces for binding-side reads. ListModel
  // get()/model.<role> reads inside bindings capture the live row proxy and
  // crash in QQmlListModel::data→captureProperty when set() mutates rows
  // (DESIGN §1.7). JS-only readers may keep using localWorkspaces.get(i).
  property var _workspaceRows: []

  property ListModel localWorkspaces: ListModel {}
  // var, not int: backend workspace ids can be strings (LabwcService) or
  // u64 (niri) — the delegate required props are var for the same reason.
  property var lastFocusedWorkspaceId: -1
  property real masterProgress: 0.0
  property bool effectsActive: false
  property color effectColor: Colors.mPrimary

  property int horizontalPadding: Style.marginS
  property int spacingBetweenPills: Style.marginXS

  // Wheel scroll handling
  property int wheelAccumulatedDelta: 0
  property bool wheelCooldown: false

  signal workspaceChanged(int workspaceId, color accentColor)

  property bool isHovered: false

  HoverHandler {
    id: workspaceHoverHandler
    enabled: showApplications && showApplicationsHover
    onHoveredChanged: {
      if (hovered) {
        hoverEval.stop();
        isHovered = true;
      } else {
        hoverEval.restart();
      }
    }
  }

  Timer {
    id: hoverEval
    interval: 150
    repeat: false
    onTriggered: {
      isHovered = workspaceHoverHandler.hovered || contextMenu.visible;
    }
  }

  readonly property bool appVisible: showApplications && (!showApplicationsHover || root.isHovered)

  implicitWidth: fashionMode ? (isVertical ? Style.dockPluginCellSize : (appVisible ? Math.round(groupedGrid.implicitWidth + horizontalPadding * hasLabel) : computeWidth())) : (appVisible ? (isVertical ? groupedGrid.implicitWidth : Math.round(groupedGrid.implicitWidth + horizontalPadding * hasLabel)) : (isVertical ? barHeight : computeWidth()))
  implicitHeight: fashionMode ? (isVertical ? (appVisible ? Math.round(groupedGrid.implicitHeight + horizontalPadding * 0.6 * hasLabel) : computeHeight()) : Style.dockPluginCellSize) : (appVisible ? (isVertical ? Math.round(groupedGrid.implicitHeight + horizontalPadding * 0.6 * hasLabel) : barHeight) : (isVertical ? computeHeight() : barHeight))

  function getWorkspaceWidth(ws, activeOverride) {
    const d = Math.round(_capsule * root.baseDimensionRatio);
    const isActive = activeOverride !== undefined ? activeOverride : ws.isActive;
    const factor = isActive ? 2.2 : 1;

    // Don't calculate text width if labels are off
    if (labelMode === "none") {
      return Style.toOdd(d * factor);
    }

    var displayText = WorkspaceQuery.labelFor(ws, labelMode, characterCount, false);

    const textWidth = displayText.length * (d * 0.4); // Approximate width per character
    const padding = d * 0.6;
    return Style.toOdd(Math.max(d * factor, textWidth + padding));
  }

  function getWorkspaceHeight(ws, activeOverride) {
    const d = Math.round(_capsule * root.baseDimensionRatio);
    const isActive = activeOverride !== undefined ? activeOverride : ws.isActive;
    const factor = isActive ? 2.2 : 1;
    return Style.toOdd(d * factor);
  }

  function computeWidth() {
    let total = 0;
    for (var i = 0; i < _workspaceRows.length; i++) {
      const ws = _workspaceRows[i];
      total += getWorkspaceWidth(ws);
    }
    total += Math.max(_workspaceRows.length - 1, 0) * spacingBetweenPills;
    total += horizontalPadding * 2;
    return Style.toOdd(total);
  }

  function computeHeight() {
    let total = 0;
    for (var i = 0; i < _workspaceRows.length; i++) {
      const ws = _workspaceRows[i];
      total += getWorkspaceHeight(ws);
    }
    total += Math.max(_workspaceRows.length - 1, 0) * spacingBetweenPills;
    total += horizontalPadding * 2;
    return Style.toOdd(total);
  }

  function getFocusedLocalIndex() {
    for (var i = 0; i < _workspaceRows.length; i++) {
      if (_workspaceRows[i].isFocused === true)
        return i;
    }
    return -1;
  }

  function switchByOffset(offset) {
    if (_workspaceRows.length <= 1)
      return;
    var current = getFocusedLocalIndex();
    if (current < 0)
      current = 0;
    var next = (current + offset) % _workspaceRows.length;
    if (next < 0)
      next = _workspaceRows.length - 1;
    if (next === current)
      return;
    const ws = _workspaceRows[next];
    if (ws && ws.idx !== undefined)
      CompositorService.switchToWorkspace(ws);
  }

  // Helper functions forwarded to the shared AppIdMatcher singleton; the
  // workspace widget keeps raw app IDs, checks pins by direct comparison only
  // (weak match) and pins the raw appId instead of the desktop entry ID.
  function isAppPinned(appId) {
    return AppIdMatcher.isAppPinned(appId);
  }

  function toggleAppPin(appId) {
    AppIdMatcher.toggleAppPin(appId, {
                                useDesktopEntryId: false
                              });
  }

  // Deferred via Qt.callLater to avoid synchronous ListModel mutations during
  // signal cascades. Qt.callLater deduplicates by function identity, so rapid
  // calls from multiple signal handlers coalesce into a single refresh.
  function scheduleRefresh() {
    if (!root.isDestroying)
      Qt.callLater(root.refreshWorkspaces);
  }

  Component.onCompleted: scheduleRefresh()

  Component.onDestruction: {
    root.isDestroying = true;
  }

  onScreenChanged: scheduleRefresh()
  onScreenNameChanged: scheduleRefresh()
  onHideUnoccupiedChanged: scheduleRefresh()
  onAppVisibleChanged: {
    if (appVisible) {
      scheduleRefresh();
    }
  }

  Connections {
    target: CompositorService
    function onWorkspacesChanged() {
      scheduleRefresh();
    }
    function onWindowListChanged() {
      if (appVisible || showLabelsOnlyWhenOccupied) {
        root.windowRevision++;
        scheduleRefresh();
      }
    }
    function onActiveWindowChanged() {
      if (appVisible) {
        root.windowRevision++;
        scheduleRefresh();
      }
    }
  }

  // Refresh icons when DesktopEntries becomes available
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      root.iconRevision++;
    }
  }

  function refreshWorkspaces() {
    var targetList = [];

    if (screen !== null) {
      // 屏幕归属筛选收敛在 Commons/WorkspaceQuery.js（与 Bar 滚轮切换共用）
      const candidates = WorkspaceQuery.workspacesForScreen(CompositorService.workspaces, {
                                                              globalWorkspaces: CompositorService.globalWorkspaces,
                                                              screenName: screen.name.toLowerCase(),
                                                              followFocusedScreen: followFocusedScreen,
                                                              focusedOutput: followFocusedScreen ? WorkspaceQuery.focusedOutput(CompositorService.workspaces) : null
                                                            });

      for (var i = 0; i < candidates.length; i++) {
        const ws = candidates[i];
        if (hideUnoccupied && !ws.isOccupied && !ws.isFocused)
          continue;

        // Plain JS row: `id` rides as `wsId` because `id` cannot be declared
        // a required property in the delegates. Values are coerced at build
        // time — backends omit fields (niri may lack is_urgent, LabwcService
        // emits string ids) and a required prop receiving undefined fails
        // delegate incubation, blanking the whole widget. Null/undefined
        // values must never reach the model either: a key that is always
        // null creates no role at all, and its required prop fails with
        // "Required property X was not initialized". Falsy stand-ins (0/"")
        // are equivalent for every consumer — backends test presence.
        var workspaceData = {
          wsId: ws.id !== undefined && ws.id !== null ? ws.id : "",
          idx: ws.idx | 0,
          name: ws.name || "",
          output: ws.output || "",
          isFocused: ws.isFocused === true,
          isActive: ws.isActive === true,
          isUrgent: ws.isUrgent === true,
          isOccupied: ws.isOccupied === true,
          handle: ws.handle || 0,
          oid: ws.oid || 0
        };

        // Windows are fetched live via liveWindows property in grouped mode
        // to avoid Qt 6.9 ListModel nested array serialization issues

        targetList.push(workspaceData);
      }
    }

    // In-place update to preserve delegates for animations
    var i = 0;
    while (i < localWorkspaces.count || i < targetList.length) {
      if (i < localWorkspaces.count && i < targetList.length) {
        var existing = localWorkspaces.get(i);
        var target = targetList[i];
        if (existing.wsId === target.wsId) {
          // Use set() to update all properties, including arrays like 'windows'
          // This is more reliable than repeated setProperty calls for complex types
          localWorkspaces.set(i, target);
          i++;
        } else {
          // ID mismatch, remove existing and re-evaluate this index
          localWorkspaces.remove(i);
        }
      } else if (i < localWorkspaces.count) {
        // Excess items in local, remove them
        localWorkspaces.remove(i);
      } else {
        // More items in target, append them
        localWorkspaces.append(targetList[i]);
        i++;
      }
    }

    root._workspaceRows = targetList;
    updateWorkspaceFocus();
  }

  function triggerUnifiedWave() {
    effectColor = Colors.mPrimary;
    masterAnimation.restart();
  }

  function updateWorkspaceFocus() {
    for (var i = 0; i < localWorkspaces.count; i++) {
      const ws = localWorkspaces.get(i);
      if (ws.isFocused === true) {
        if (root.lastFocusedWorkspaceId !== -1 && root.lastFocusedWorkspaceId !== ws.wsId) {
          root.triggerUnifiedWave();
        }
        root.lastFocusedWorkspaceId = ws.wsId;
        root.workspaceChanged(ws.wsId, Colors.mPrimary);
        break;
      }
    }
  }

  SequentialAnimation {
    id: masterAnimation
    PropertyAction {
      target: root
      property: "effectsActive"
      value: true
    }
    NAnim {
      target: root
      property: "masterProgress"
      from: 0.0
      to: 1.0
      duration: Style.motionPanel
      curve: "out"
    }
    PropertyAction {
      target: root
      property: "effectsActive"
      value: false
    }
    PropertyAction {
      target: root
      property: "masterProgress"
      value: 0.0
    }
  }

  NPopupContextMenu {
    id: contextMenu

    onVisibleChanged: {
      if (visible) {
        hoverEval.stop();
        root.isHovered = true;
      } else {
        hoverEval.restart();
      }
    }

    model: {
      var items = [];
      if (root.selectedWindowId) {
        // Focus item
        items.push({
                     "label": I18n.tr("common.focus"),
                     "action": "focus",
                     "icon": "eye"
                   });

        // Pin/Unpin item
        const isPinned = root.isAppPinned(root.selectedAppId);
        items.push({
                     "label": !isPinned ? I18n.tr("common.pin") : I18n.tr("common.unpin"),
                     "action": "pin",
                     "icon": !isPinned ? "pin" : "pinned-off"
                   });

        // Close item
        items.push({
                     "label": I18n.tr("common.close"),
                     "action": "close",
                     "icon": "x"
                   });

        // Add desktop entry actions
        if (typeof DesktopEntries !== 'undefined' && DesktopEntries.byId && root.selectedAppId) {
          const entry = (DesktopEntries.heuristicLookup) ? DesktopEntries.heuristicLookup(root.selectedAppId) : DesktopEntries.byId(root.selectedAppId);
          if (entry != null && entry.actions) {
            entry.actions.forEach(function (action) {
              items.push({
                           "label": action.name,
                           "action": "desktop-action-" + action.name,
                           "icon": "chevron-right",
                           "desktopAction": action
                         });
            });
          }
        }
      }
      items.push({
                   "label": I18n.tr("actions.widget-settings"),
                   "action": "widget-settings",
                   "icon": "settings"
                 });
      return items;
    }

    onTriggered: (action, item) => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   const selectedWindow = root.getSelectedWindow();

                   if (action === "focus" && selectedWindow) {
                     CompositorService.focusWindow(selectedWindow);
                   } else if (action === "pin" && selectedAppId) {
                     root.toggleAppPin(selectedAppId);
                   } else if (action === "close" && selectedWindow) {
                     CompositorService.closeWindow(selectedWindow);
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   } else if (action.startsWith("desktop-action-") && item && item.desktopAction) {
                     if (item.desktopAction.command && item.desktopAction.command.length > 0) {
                       Quickshell.execDetached(item.desktopAction.command);
                     } else if (item.desktopAction.execute) {
                       item.desktopAction.execute();
                     }
                   }
                   selectedWindowId = "";
                   selectedAppId = "";
                 }
  }

  Rectangle {
    id: workspaceBackground
    visible: !appVisible
    width: isVertical ? _capsule : parent.width
    height: isVertical ? parent.height : _capsule
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    x: isVertical ? Style.pixelAlignCenter(parent.width, width) : 0
    y: isVertical ? 0 : Style.pixelAlignCenter(parent.height, height)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      onClicked: mouse => {
                   if (mouse.button === Qt.RightButton) {
                     PanelService.showContextMenu(contextMenu, workspaceBackground, screen);
                   }
                 }
    }
  }

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

  // Scroll to switch workspaces
  WheelHandler {
    id: wheelHandler
    target: root
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    enabled: root.enableScrollWheel
    onWheel: function (event) {
      if (root.wheelCooldown)
        return;
      // Prefer vertical delta, fall back to horizontal if needed
      var dy = event.angleDelta.y;
      var dx = event.angleDelta.x;
      var useDy = Math.abs(dy) >= Math.abs(dx);
      var delta = useDy ? dy : dx;
      // One notch is typically 120
      root.wheelAccumulatedDelta += delta;
      var step = 120;
      if (Math.abs(root.wheelAccumulatedDelta) >= step) {
        var direction = root.wheelAccumulatedDelta > 0 ? -1 : 1;
        if (root.reverseScroll)
          direction *= -1;
        // For vertical layout, natural mapping: wheel up -> previous, down -> next (already handled by sign)
        // For horizontal layout, same mapping using vertical wheel
        root.switchByOffset(direction);
        root.wheelCooldown = true;
        wheelDebounce.restart();
        root.wheelAccumulatedDelta = 0;
        event.accepted = true;
      }
    }
  }

  // Horizontal layout for top/bottom bars
  Row {
    id: pillRow
    spacing: spacingBetweenPills
    x: horizontalPadding
    y: root.fashionMode ? Style.pixelAlignCenter(parent.height, height) : 0
    visible: !isVertical && !appVisible
    scale: visible ? 1.0 : 0.8
    Behavior on scale {
      NAnim {
        duration: Style.motionSwitch
        curve: "overshoot"
      }
    }

    Repeater {
      id: workspaceRepeaterHorizontal
      model: localWorkspaces
      delegate: WorkspacePill {
        // Row roles as required properties — the engine writes updates on
        // set(); model.<role>/get() reads in bindings capture the live row
        // proxy and crash (DESIGN §1.7). `id` rides as `wsId`. All `var`:
        // backend workspaces vary per compositor (string ids, absent flags) —
        // a typed required prop receiving undefined kills the whole delegate.
        required property var wsId
        required property var idx
        required property var name
        required property var output
        required property var isFocused
        required property var isActive
        required property var isUrgent
        required property var isOccupied
        required property var handle
        required property var oid
        workspace: ({
                      "id": wsId,
                      "idx": idx,
                      "name": name,
                      "output": output,
                      "isFocused": isFocused,
                      "isActive": isActive,
                      "isUrgent": isUrgent,
                      "isOccupied": isOccupied,
                      "handle": handle,
                      "oid": oid
                    })
        isVertical: false
        baseDimensionRatio: root.baseDimensionRatio
        capsuleHeight: root._capsule
        barHeight: root.fashionMode ? Style.dockPluginCellSize : root.barHeight
        labelMode: root.labelMode
        fontWeight: root.fontWeight
        characterCount: root.characterCount
        textRatio: root.textRatio
        showLabelsOnlyWhenOccupied: root.showLabelsOnlyWhenOccupied
        focusedColor: root.focusedColor
        occupiedColor: root.occupiedColor
        emptyColor: root.emptyColor
        masterProgress: root.masterProgress
        effectsActive: root.effectsActive
        effectColor: root.effectColor
        getWorkspaceWidth: root.getWorkspaceWidth
        getWorkspaceHeight: root.getWorkspaceHeight
      }
    }
  }

  // Vertical layout for left/right bars
  Column {
    id: pillColumn
    spacing: spacingBetweenPills
    x: root.fashionMode ? Style.pixelAlignCenter(parent.width, width) : 0
    y: horizontalPadding
    visible: isVertical && !appVisible
    scale: visible ? 1.0 : 0.8
    Behavior on scale {
      NAnim {
        duration: Style.motionSwitch
        curve: "overshoot"
      }
    }

    Repeater {
      id: workspaceRepeaterVertical
      model: localWorkspaces
      delegate: WorkspacePill {
        // Row roles as required properties — see the horizontal repeater.
        required property var wsId
        required property var idx
        required property var name
        required property var output
        required property var isFocused
        required property var isActive
        required property var isUrgent
        required property var isOccupied
        required property var handle
        required property var oid
        workspace: ({
                      "id": wsId,
                      "idx": idx,
                      "name": name,
                      "output": output,
                      "isFocused": isFocused,
                      "isActive": isActive,
                      "isUrgent": isUrgent,
                      "isOccupied": isOccupied,
                      "handle": handle,
                      "oid": oid
                    })
        isVertical: true
        baseDimensionRatio: root.baseDimensionRatio
        capsuleHeight: root._capsule
        barHeight: root.fashionMode ? Style.dockPluginCellSize : root.barHeight
        labelMode: root.labelMode
        fontWeight: root.fontWeight
        characterCount: root.characterCount
        textRatio: root.textRatio
        showLabelsOnlyWhenOccupied: root.showLabelsOnlyWhenOccupied
        focusedColor: root.focusedColor
        occupiedColor: root.occupiedColor
        emptyColor: root.emptyColor
        masterProgress: root.masterProgress
        effectsActive: root.effectsActive
        effectColor: root.effectColor
        getWorkspaceWidth: root.getWorkspaceWidth
        getWorkspaceHeight: root.getWorkspaceHeight
      }
    }
  }

  // ========================================
  // Grouped mode (appVisible = true)
  // ========================================
  Component {
    id: groupedWorkspaceDelegate

    Rectangle {
      id: groupedContainer

      // Row roles as required properties — same recipe as the pill delegates;
      // all `var` because backend fields differ per compositor (undefined on a
      // typed required prop would kill the delegate).
      required property var wsId
      required property var idx
      required property var name
      required property var output
      required property var isFocused
      required property var isActive
      required property var isUrgent
      required property var isOccupied
      required property var handle
      required property var oid
      property var workspaceModel: ({
                                      "id": wsId,
                                      "idx": idx,
                                      "name": name,
                                      "output": output,
                                      "isFocused": isFocused,
                                      "isActive": isActive,
                                      "isUrgent": isUrgent,
                                      "isOccupied": isOccupied,
                                      "handle": handle,
                                      "oid": oid
                                    })
      // Fetch windows directly from service to avoid Qt 6.9 ListModel nested array issues
      property var liveWindows: []
      // Inert entry for delegates that briefly outlive a shrunken liveWindows array
      readonly property var emptyWindowEntry: ({
                                                 "id": "",
                                                 "appId": "",
                                                 "title": "",
                                                 "isFocused": false,
                                                 "workspaceId": -1,
                                                 "address": ""
                                               })
      property bool hasWindows: liveWindows.length > 0

      function updateWindows() {
        var wsId = workspaceModel?.id;
        if (wsId !== undefined && wsId !== null) {
          liveWindows = CompositorService.getWindowsForWorkspace(wsId);
        } else {
          liveWindows = [];
        }
      }

      // Deferred to avoid re-entrant incubation: when localWorkspaces.append()
      Component.onCompleted: Qt.callLater(updateWindows)
      onWorkspaceModelChanged: Qt.callLater(updateWindows)

      Connections {
        target: root
        function onWindowRevisionChanged() {
          Qt.callLater(groupedContainer.updateWindows);
        }
      }

      HoverHandler {
        id: groupHoverHandler
      }

      width: Style.toOdd((hasWindows ? groupedIconsFlow.implicitWidth : root.iconSize) + (root.isVertical ? (root.baseItemSize - root.iconSize + Style.marginXS) : Style.marginXL))
      height: Style.toOdd((hasWindows ? groupedIconsFlow.implicitHeight : root.iconSize) + (root.isVertical ? Style.marginL : (root.baseItemSize - root.iconSize + Style.marginXS)))
      color: Style.capsuleColor
      radius: Style.radiusS
      border.color: Settings.data.bar.showOutline ? Style.capsuleBorderColor : Qt.alpha((workspaceModel.isFocused ? Colors.mPrimary : (groupHoverHandler.hovered ? Colors.mHover : Colors.mOutline)), root.groupedBorderOpacity)
      border.width: Style.borderS

      Behavior on width {
        NAnim {
          duration: Style.motionExpand
          curve: "expand"
        }
      }
      Behavior on height {
        NAnim {
          duration: Style.motionExpand
          curve: "expand"
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        onPressed: mouse => {
                     if (mouse.button === Qt.LeftButton) {
                       CompositorService.switchToWorkspace(groupedContainer.workspaceModel);
                     }
                   }
        onReleased: mouse => {
                      if (mouse.button === Qt.RightButton) {
                        mouse.accepted = true;
                        TooltipService.hide();
                        root.selectedWindowId = "";
                        root.selectedAppId = "";
                        openGroupedContextMenu(groupedContainer);
                      }
                    }
      }

      Flow {
        id: groupedIconsFlow

        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        spacing: 2
        flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight

        // Model is the count, entries are read by index: a rebuilt snapshot
        // array of equal length would otherwise recreate every delegate
        Repeater {
          model: groupedContainer.liveWindows.length

          delegate: Item {
            id: groupedTaskbarItem

            required property int index
            readonly property var modelData: groupedContainer.liveWindows[index] ?? groupedContainer.emptyWindowEntry

            readonly property bool isFocused: modelData?.isFocused ?? false

            width: root.iconSize
            height: root.iconSize

            HoverHandler {
              id: windowHoverHandler
            }

            IconImage {
              id: groupedAppIcon

              width: parent.width
              height: parent.height

              source: {
                root.iconRevision; // Force re-evaluation when revision changes
                return ThemeIcons.iconForAppId(modelData?.appId);
              }
              smooth: true
              asynchronous: true
              opacity: groupedTaskbarItem.isFocused ? Style.opacityFull : unfocusedIconsOpacity
              layer.enabled: root.colorizeIcons && !groupedTaskbarItem.isFocused

              Rectangle {
                id: groupedFocusIndicator
                visible: groupedTaskbarItem.isFocused || windowHoverHandler.hovered
                anchors.bottomMargin: -2
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.toOdd(root.iconSize * 0.25)
                height: 4
                color: groupedTaskbarItem.isFocused ? Colors.mPrimary : Colors.mHover
                radius: Math.min(Style.radiusXXS, width / 2)
              }

              layer.effect: ShaderEffect {
                property color targetColor: Settings.data.colorSchemes.darkMode ? Colors.mOnSurface : Colors.mSurfaceVariant
                property real colorizeMode: 0
                fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              preventStealing: true

              onPressed: mouse => {
                           if (mouse.button === Qt.LeftButton && modelData) {
                             CompositorService.focusWindow(modelData);
                           }
                         }

              onReleased: mouse => {
                            if (mouse.button === Qt.RightButton && modelData) {
                              mouse.accepted = true;
                              TooltipService.hide();
                              root.selectedWindowId = modelData.id || modelData.address || "";
                              root.selectedAppId = modelData.appId;
                              openGroupedContextMenu(groupedTaskbarItem);
                            }
                          }
              onEntered: {
                if (!modelData)
                  return;
                TooltipService.show(groupedTaskbarItem, modelData.title || modelData.appId || "Unknown app.", BarService.getTooltipDirection(root.screenName, root.section === "dock"));
              }
              onExited: {
                TooltipService.hide();
              }
            }
          }
        }
      }

      Item {
        id: groupedWorkspaceNumberContainer

        visible: root.labelMode !== "none" && root.showBadge && (!root.showLabelsOnlyWhenOccupied || groupedContainer.hasWindows || groupedContainer.workspaceModel.isFocused)

        anchors {
          left: parent.left
          top: parent.top
          leftMargin: -Style.fontSizeXS * 0.55
          topMargin: -Style.fontSizeXS * 0.25
        }

        width: Math.max(groupedWorkspaceNumber.implicitWidth + Style.margin2XS, Style.fontSizeXXS * 2)
        height: Math.max(groupedWorkspaceNumber.implicitHeight + Style.marginXS, Style.fontSizeXXS * 2)

        Rectangle {
          id: groupedWorkspaceNumberBackground

          anchors.fill: parent
          radius: Math.min(Style.radiusL, width / 2)

          color: {
            if (groupedContainer.workspaceModel.isFocused)
              return Colors.resolveColorKey(root.focusedColor);
            if (groupedContainer.workspaceModel.isUrgent)
              return Colors.mError;
            if (groupedContainer.hasWindows)
              return Colors.resolveColorKey(root.occupiedColor);

            return Colors.resolveColorKey(root.emptyColor);
          }

          scale: groupedContainer.workspaceModel.isActive ? 1.0 : 0.8

          Behavior on scale {
            NAnim {
              duration: Style.motionSwitch
              curve: "overshoot"
            }
          }

          Behavior on color {
            enabled: !Colors.isTransitioning
            NColorAnim {
              duration: Style.motionSwitch
              curve: "swift"
            }
          }
        }

        // Burst effect overlay for focused workspace number
        Rectangle {
          id: groupedWorkspaceNumberBurst
          anchors.centerIn: groupedWorkspaceNumberContainer
          width: groupedWorkspaceNumberContainer.width + 12 * root.masterProgress
          height: groupedWorkspaceNumberContainer.height + 12 * root.masterProgress
          radius: width / 2
          color: "transparent"
          border.color: root.effectColor
          border.width: Math.max(1, Math.round((2 + 4 * (1.0 - root.masterProgress))))
          opacity: root.effectsActive && groupedContainer.workspaceModel.isFocused ? (1.0 - root.masterProgress) * 0.7 : 0
          visible: root.effectsActive && groupedContainer.workspaceModel.isFocused
          z: 1
        }

        NText {
          id: groupedWorkspaceNumber

          anchors.centerIn: parent

          text: WorkspaceQuery.labelFor(groupedContainer.workspaceModel, root.labelMode, root.characterCount, true)

          family: Settings.data.ui.fontFixed
          font {
            pointSize: barFontSize * 0.75
            weight: fontWeight
            capitalization: Font.AllUppercase
          }
          applyUiScale: false

          color: {
            if (groupedContainer.workspaceModel.isFocused)
              return Colors.resolveOnColorKey(root.focusedColor);
            if (groupedContainer.workspaceModel.isUrgent)
              return Colors.mOnError;
            if (groupedContainer.hasWindows)
              return Colors.resolveOnColorKey(root.occupiedColor);

            return Colors.resolveOnColorKey(root.emptyColor);
          }

          Behavior on opacity {
            NAnim {
              duration: Style.motionExpand
              curve: "out"
            }
          }
        }

        Behavior on opacity {
          NAnim {
            duration: Style.motionExpand
            curve: "out"
          }
        }
      }
    }
  }

  Flow {
    id: groupedGrid
    visible: appVisible
    scale: visible ? 1.0 : 0.8
    Behavior on scale {
      NAnim {
        duration: Style.motionSwitch
        curve: "overshoot"
      }
    }

    x: root.isVertical ? Style.pixelAlignCenter(parent.width, width) : Math.round(horizontalPadding * root.hasLabel)
    y: root.isVertical ? Math.round(horizontalPadding * 0.4 * root.hasLabel) : Style.pixelAlignCenter(parent.height, height)

    spacing: Style.marginS
    flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight

    Repeater {
      model: appVisible ? localWorkspaces : null
      delegate: groupedWorkspaceDelegate
    }
  }

  function openGroupedContextMenu(item) {
    // Anchor to root (stable) but center horizontally on the clicked item
    PanelService.showContextMenu(contextMenu, root, screen, item);
  }
}
