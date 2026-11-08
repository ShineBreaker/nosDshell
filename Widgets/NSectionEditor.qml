import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Plugins
import qs.Services.UI
import qs.Widgets

// Sectioned widget-layout editor — one zone is one titled SettingsGroup
// (DESIGN §3.5.4 列表页): the zone name is the group's in-block head, every
// installed widget is a row (name + plugin/cpu badges + settings gear), and
// the tail row is the "add widget" picker. Rows reorder by left-drag, move
// across sibling zones by dropping on the target group, and right-click
// offers move-to/remove. `editMode` hosts: the status bar and taskbar
// (MonitorWidgetsConfig), control-center shortcuts (ShortcutsSubTab) and
// per-monitor desktop widgets (DesktopWidgetsTab).
Item {
  id: root

  property string sectionName: ""
  property string sectionSubtitle: ""
  property string sectionId: ""
  property var widgetModel: []
  property var availableWidgets: []
  property var availableSections: ["left", "center", "right"]
  property var sectionLabels: ({}) // Map of sectionId -> display label
  property var sectionIcons: ({}) // Map of sectionId -> icon name
  property bool barIsVertical: false // When true, map left/right to top/bottom in labels
  property int maxWidgets: -1 // -1 means unlimited
  property bool draggable: true // Enable/disable drag reordering
  property bool crossSectionDraggable: false
  // Cross-zone drops land anywhere on the group — head, rows and the add
  // row all count (updateCrossSectionHover / findSectionAtGlobalPosition).
  property alias dropTargetArea: group

  // Get display label for a section
  function getSectionLabel(sectionId) {
    if (sectionLabels && sectionLabels[sectionId]) {
      return sectionLabels[sectionId];
    }
    return sectionId; // Fallback to section ID
  }

  // Get icon for a section
  function getSectionIcon(sectionId) {
    if (sectionIcons && sectionIcons[sectionId]) {
      return sectionIcons[sectionId];
    }
    return "arrow-right"; // Default fallback icon
  }

  property var pluginSettingsEntryPoints: ["settings"]
  property var widgetRegistry: null
  property string settingsDialogComponent: "invalid-settings-dialog"
  property var screen: null // Screen reference for per-screen widget settings
  property var _activeDialog: null
  property bool crossDropHoverActive: false
  property int _contextIndex: -1

  // Render model — widgetModel is a freshly-computed JS array; assigning it to
  // the Repeater wholesale is QQuickRepeater::setModel → incubate, and a notify
  // re-entering during that incubation corrupts the V4 heap (the
  // QV4::Object::insertMember SIGSEGV class — same guard as Bar._initModels).
  // The Repeater renders widgetRows, a stable ListModel synced incrementally
  // one event-loop turn after widgetModel changes. Rows carry no payload —
  // delegates resolve their entry live from widgetModel[index] (QObject
  // payloads in ListModel roles can dangle into teardown — QQmlListModel::data
  // crash class).
  ListModel {
    id: widgetRows
  }
  property bool _destroyed: false
  property bool _widgetSyncQueued: false
  function _queueWidgetSync() {
    if (_widgetSyncQueued)
      return;
    _widgetSyncQueued = true;
    Qt.callLater(_syncWidgetRowsNow);
  }
  onWidgetModelChanged: _queueWidgetSync()
  function _syncWidgetRowsNow() {
    _widgetSyncQueued = false;
    if (_destroyed)
      return;
    var list = widgetModel || [];
    while (widgetRows.count < list.length)
      widgetRows.append({
                          "row": 1
                        });
    while (widgetRows.count > list.length)
      widgetRows.remove(widgetRows.count - 1);
  }

  function clearCrossSectionHover() {
    crossDropHoverActive = false;

    var parentItem = root.parent;
    if (!parentItem || !parentItem.children) {
      return;
    }

    for (var i = 0; i < parentItem.children.length; i++) {
      var candidate = parentItem.children[i];
      if (!candidate || candidate.crossDropHoverActive === undefined)
        continue;
      candidate.crossDropHoverActive = false;
    }
  }

  function updateCrossSectionHover(globalX, globalY) {
    var parentItem = root.parent;
    if (!parentItem || !parentItem.children) {
      crossDropHoverActive = false;
      return;
    }

    crossDropHoverActive = false;

    for (var i = 0; i < parentItem.children.length; i++) {
      var candidate = parentItem.children[i];
      if (!candidate || candidate.sectionId === undefined || candidate.crossDropHoverActive === undefined) {
        continue;
      }

      var shouldHighlight = false;
      if (candidate !== root && candidate.visible && candidate.enabled) {
        var localPoint = candidate.mapFromGlobal(globalX, globalY);
        var area = candidate.dropTargetArea ? candidate.dropTargetArea : candidate;
        shouldHighlight = localPoint.x >= area.x && localPoint.y >= area.y && localPoint.x <= area.x + area.width && localPoint.y <= area.y + area.height;
      }

      candidate.crossDropHoverActive = shouldHighlight;
    }
  }

  function isPointInsideSelf(globalX, globalY) {
    if (globalX < 0 || globalY < 0)
      return false;
    var localPoint = root.mapFromGlobal(globalX, globalY);
    return localPoint.x >= 0 && localPoint.y >= 0 && localPoint.x <= root.width && localPoint.y <= root.height;
  }

  function findSectionAtGlobalPosition(globalX, globalY) {
    var parentItem = root.parent;
    if (!parentItem || !parentItem.children) {
      return "";
    }

    for (var i = 0; i < parentItem.children.length; i++) {
      var candidate = parentItem.children[i];
      if (!candidate || candidate === root) {
        continue;
      }

      // Only consider sibling section editors
      if (candidate.sectionId === undefined || !candidate.visible || !candidate.enabled) {
        continue;
      }

      var localPoint = candidate.mapFromGlobal(globalX, globalY);
      var area = candidate.dropTargetArea ? candidate.dropTargetArea : candidate;
      if (localPoint.x >= area.x && localPoint.y >= area.y && localPoint.x <= area.x + area.width && localPoint.y <= area.y + area.height) {
        return candidate.sectionId;
      }
    }

    return "";
  }

  readonly property bool showCrossSectionDropHint: crossDropHoverActive

  Component.onCompleted: _queueWidgetSync()
  Component.onDestruction: {
    _destroyed = true;
    if (_activeDialog && _activeDialog.close) {
      var dialog = _activeDialog;
      _activeDialog = null;
      dialog.close();
      dialog.destroy();
    }
  }

  readonly property real miniButtonSize: Style.baseWidgetSize * 0.65
  readonly property bool isAtMaxCapacity: maxWidgets >= 0 && widgetModel.length >= maxWidgets

  signal addWidget(string widgetId, string section)
  signal removeWidget(string section, int index)
  signal reorderWidget(string section, int fromIndex, int toIndex)
  signal updateWidgetSettings(string section, int index, var settings)
  signal moveWidget(string fromSection, int index, string toSection)
  signal dragPotentialStarted
  signal dragPotentialEnded
  signal openPluginSettingsRequested(var pluginManifest, string settingsEntryPoint)

  Layout.fillWidth: true
  implicitHeight: group.implicitHeight
  z: flowDragArea?.dragStarted ? 5000 : 0

  // The head's right-edge note: the subtitle (a monitor's resolution on the
  // desktop-widgets page) and/or the capacity counter — the dcc
  // SettingsHeaderItem right-widget slot (settingsheaderitem.cpp:52).
  readonly property string _headNote: {
    var parts = [];
    if (root.sectionSubtitle !== "")
      parts.push(root.sectionSubtitle);
    if (root.maxWidgets >= 0)
      parts.push(root.maxWidgets === 0 ? "(LOCKED)" : "(" + widgetModel.length + "/" + root.maxWidgets + ")");
    return parts.join(" ");
  }

  // Check if widget has settings (either core widget with metadata or plugin with settings entry point)
  function widgetHasSettings(widgetId) {
    // Check if it's a plugin with settings
    if (root.widgetRegistry && root.widgetRegistry.isPluginWidget(widgetId)) {
      var pluginId = widgetId.replace("plugin:", "");
      var manifest = PluginRegistry.getPluginManifest(pluginId);
      if (!manifest?.entryPoints)
        return false;
      for (var i = 0; i < root.pluginSettingsEntryPoints.length; i++) {
        if (manifest.entryPoints[root.pluginSettingsEntryPoints[i]] !== undefined)
          return true;
      }
      return false;
    }

    // Check if it's a core widget with user settings
    if (root.widgetRegistry && root.widgetRegistry.widgetHasUserSettings(widgetId)) {
      return true;
    }

    return false;
  }

  function widgetDisplayName(widgetId) {
    // Localised label from the registry (plugin ids resolve to the manifest
    // name inside); falls back to the raw id when no display name exists.
    if (root.widgetRegistry && typeof root.widgetRegistry.widgetDisplayName === "function") {
      return root.widgetRegistry.widgetDisplayName(widgetId);
    }
    return widgetId;
  }

  // Open settings for a widget
  function openWidgetSettings(index, widgetData) {
    // Check if this is a plugin widget with a generic "settings" entry point
    var isPlugin = root.widgetRegistry && root.widgetRegistry.isPluginWidget(widgetData.id);

    if (isPlugin) {
      var pluginId = widgetData.id.replace("plugin:", "");
      var manifest = PluginRegistry.getPluginManifest(pluginId);

      var settingsKey = null;
      if (manifest?.entryPoints) {
        for (var i = 0; i < root.pluginSettingsEntryPoints.length; i++) {
          if (manifest.entryPoints[root.pluginSettingsEntryPoints[i]] !== undefined) {
            settingsKey = root.pluginSettingsEntryPoints[i];
            break;
          }
        }
      }
      if (!manifest || !settingsKey) {
        Logger.e("NSectionEditor", "Plugin settings not found for:", pluginId);
        return;
      }

      // "desktopWidgetSettings" is handled by the settingsDialogComponent
      // (DesktopWidgetSettingsDialog) which passes widgetSettings/save properly.
      // Only generic "settings" goes through the plugin settings popup.
      if (settingsKey !== "desktopWidgetSettings") {
        root.openPluginSettingsRequested(manifest, settingsKey);
        return;
      }
    }

    // Handle core widgets and plugin desktop widget settings
    {
      var component = Qt.createComponent(Qt.resolvedUrl(root.settingsDialogComponent));

      function instantiateAndOpen() {
        if (root._activeDialog) {
          try {
            root._activeDialog.close();
            root._activeDialog.destroy();
          } catch (e) {}
          root._activeDialog = null;
        }

        // Host the dialog on the per-screen popup window when one exists:
        // that surface owns the dialog blur region (PopupMenuWindow's
        // dialogBlurRegion) and the click-outside close — a Popup on this
        // window's Overlay.overlay renders on the settings surface itself,
        // which has no blur region for the dialog rect.
        var dlgScreen = root.screen || PanelService.findFallbackScreen();
        var popupWin = dlgScreen ? PanelService.getPopupMenuWindow(dlgScreen) : null;
        var dialogParent = popupWin ? popupWin.dialogParent : Overlay.overlay;
        var dialog = component.createObject(dialogParent, {
                                              "widgetIndex": index,
                                              "widgetData": widgetData,
                                              "widgetId": widgetData.id,
                                              "sectionId": root.sectionId,
                                              "screen": dlgScreen,
                                              "barIsVertical": root.barIsVertical
                                            });

        if (dialog) {
          root._activeDialog = dialog;
          dialog.updateWidgetSettings.connect(root.updateWidgetSettings);
          if (popupWin)
            popupWin.hostDialog(dialog);
          dialog.closed.connect(() => {
            if (root._activeDialog === dialog) {
              root._activeDialog = null;
              dialog.destroy();
            }
          });
          dialog.open();
        } else {
          Logger.e("NSectionEditor", "Failed to create settings dialog instance");
        }
      }

      if (component.status === Component.Ready) {
        instantiateAndOpen();
      } else if (component.status === Component.Error) {
        Logger.e("NSectionEditor", component.errorString());
      } else {
        component.statusChanged.connect(function () {
          if (component.status === Component.Ready) {
            instantiateAndOpen();
          } else if (component.status === Component.Error) {
            Logger.e("NSectionEditor", component.errorString());
          }
        });
      }
    }
  }

  NSettingsGroup {
    id: group
    anchors.fill: parent
    title: root.sectionName
    titleNote: root._headNote

    Repeater {
      id: widgetRepeater
      model: widgetRows

      delegate: NDccRow {
        id: widgetItem
        required property int index
        readonly property var modelData: (root.widgetModel && index >= 0 && index < root.widgetModel.length) ? root.widgetModel[index] : ({
                                                                                                                                            "id": ""
                                                                                                                                          })

        // Store the widget index for drag operations
        property int widgetIndex: index
        // The gear's painted tile, not a separate 20 px guess.
        readonly property int buttonsWidth: Style.toOdd(root.miniButtonSize * Style.uiScaleRatio)
        readonly property int buttonsCount: root.widgetHasSettings(modelData.id) ? 1 : 0
        // x of the gear slot inside the row — the drag and context handlers
        // treat presses right of this line as button presses, not drags.
        readonly property real buttonsStartX: width - Style.settingsRowPaddingH - buttonsCount * buttonsWidth

        interactive: enabled

        // Visual feedback during drag; dim the whole row when the editor
        // subtree is disabled (same 0.6 as NToggle/NComboBox).
        opacity: flowDragArea?.draggedIndex === index ? 0.5 : (enabled ? 1.0 : 0.6)
        scale: flowDragArea?.draggedIndex === index ? 0.95 : 1.0
        z: flowDragArea?.draggedIndex === index ? 1000 : 0

        Behavior on opacity {
          NAnim {
            duration: Style.motionPointer
            curve: "swift"
          }
        }
        Behavior on scale {
          NAnim {
            duration: Style.motionPointer
            curve: "swift"
          }
        }

        NText {
          id: widgetLabel
          text: root.widgetDisplayName(modelData.id)
          // widgetItem already dims the whole row when disabled.
          autoDim: false
          color: Colors.onShell
          elide: Text.ElideRight
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
        }

        // Plugin indicator icon
        NIcon {
          visible: root.widgetRegistry && root.widgetRegistry.isPluginWidget(modelData.id)
          icon: "plugin"
          pointSize: Style.fontSizeXS
          color: Colors.onShell
          Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.5 : 0
          Layout.preferredHeight: Style.baseWidgetSize * 0.5
          Layout.alignment: Qt.AlignVCenter
        }

        // CPU intensive indicator icon
        NIcon {
          visible: root.widgetRegistry && root.widgetRegistry.isCpuIntensive(modelData.id)
          icon: "cpu-intensive"
          pointSize: Style.fontSizeXS
          color: Colors.onShell
          Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.5 : 0
          Layout.preferredHeight: Style.baseWidgetSize * 0.5
          Layout.alignment: Qt.AlignVCenter
        }

        Loader {
          // Hidden when empty — a visible 0-wide item still receives the
          // RowLayout spacing and that gap is taken from the label.
          visible: buttonsCount > 0
          active: buttonsCount > 0 && root.enabled
          Layout.preferredWidth: buttonsCount > 0 ? buttonsWidth : 0
          Layout.preferredHeight: buttonsWidth
          Layout.alignment: Qt.AlignVCenter
          sourceComponent: NIconButton {
            // objectName lets `debug find` locate a widget's gear in verify
            // scenes (hit-testing can't reach 25-deep rows); sectionId
            // disambiguates the same widget across editors.
            objectName: "widgetGear-" + root.sectionId + "-" + (modelData.id || "")
            icon: "settings"
            tooltipText: I18n.tr("actions.widget-settings")
            baseSize: miniButtonSize
            colorBorder: "transparent"
            colorBg: Colors.overlay("hover")
            colorFg: Colors.onShell
            colorBgHover: Colors.overlay("checked")
            colorFgHover: Colors.onShell
            onClicked: {
              root.openWidgetSettings(index, modelData);
            }
          }
        }
      }
    }

    // Tail row: the add-widget picker. A labelled combo IS a settings row
    // (§3.5.4 combo row); selecting an entry adds it straight away, so the
    // row never carries a committed selection (currentKey stays "").
    NSearchableComboBox {
      id: comboBox
      Layout.fillWidth: true
      model: availableWidgets ?? null
      label: I18n.tr("tooltips.add-widget")
      description: ""
      placeholder: I18n.tr("bar.section-editor.placeholder")
      searchPlaceholder: I18n.tr("bar.section-editor.search-placeholder")
      enabled: root.enabled && !root.isAtMaxCapacity
      // selectOnNavigation fires `selected` on every up/down in the popup —
      // here `selected` means "add the widget", so only click/Enter may emit.
      selectOnNavigation: false
      onSelected: key => {
        if (!root.isAtMaxCapacity) {
          root.addWidget(key, root.sectionId);
          currentKey = "";
        }
      }

      // Re-filter when the model count changes (when widgets are loaded)
      Connections {
        target: availableWidgets ?? null
        ignoreUnknownSignals: true
        function onCountChanged() {
          // Trigger a re-filter by clearing and re-setting the search text
          var currentSearch = comboBox.searchText;
          comboBox.searchText = "";
          comboBox.searchText = currentSearch;
        }
      }
    }
  }

  // Cross-section drop highlight — covers the whole group so a drop anywhere
  // on the zone reads as landing in it.
  Rectangle {
    anchors.fill: parent
    radius: Style.radiusItem
    color: Qt.alpha(Colors.accent, 0.12)
    border.color: Colors.accent
    border.width: Style.borderM
    visible: root.showCrossSectionDropHint
    z: 1500
  }

  // Ghost/Clone widget for dragging
  Rectangle {
    id: dragGhost
    width: 0
    height: Style.settingsRowHeight
    radius: Style.radiusItem
    color: "transparent"
    border.color: Colors.borderShell
    border.width: Style.borderS
    opacity: 0.7
    visible: flowDragArea?.dragStarted === true
    z: 2000
    clip: false // Ensure ghost isn't clipped

    NText {
      id: ghostText
      anchors.centerIn: parent
      pointSize: Style.fontSizeS
      color: Colors.onShell
    }
  }

  // Drop indicator — a horizontal accent line on the seam where the widget
  // will be inserted (the rows are a vertical list now).
  Rectangle {
    id: dropIndicator
    x: Style.radiusItem
    width: root.width - Style.radiusItem * 2
    height: 3
    radius: Style.radiusRow
    color: Colors.accent
    opacity: 0
    visible: opacity > 0
    z: 1999
    // Set by the drag handlers; the pulse runs only while it is set and
    // motion is not reduced. Under reduced motion the handlers' opacity 1
    // shows the indicator without the pulse. (Binding `paused` instead
    // warned "setPaused() cannot be used when animation isn't running"
    // every time reduced motion turned on outside a drag.)
    property bool pulsing: false

    SequentialAnimation on opacity {
      id: pulseAnimation
      running: dropIndicator.pulsing && !Style.reduceMotion
      loops: Animation.Infinite
      NAnim {
        to: 1
        duration: Style.motionPulse
        curve: "pulse"
      }
      NAnim {
        to: 0.6
        duration: Style.motionPulse
        curve: "pulse"
      }
    }

    Behavior on y {
      NAnim {
        duration: Style.animationFaster
        curve: "out"
      }
    }
  }

  // Right-click context menu — shared by every row (the model only depends
  // on the sibling sections); _contextIndex remembers which row opened it.
  MouseArea {
    id: contextArea
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    enabled: !(flowDragArea?.dragStarted || flowDragArea?.potentialDrag)

    onPressed: mouse => {
      for (var i = 0; i < widgetModel.length; i++) {
        var row = widgetRepeater.itemAt(i);
        if (!row || row.widgetIndex === undefined)
          continue;
        if (mouse.x >= row.x && mouse.x <= row.x + row.width && mouse.y >= row.y && mouse.y <= row.y + row.height) {
          // Right-click on the gear area is the gear's business.
          if (row.buttonsCount > 0 && mouse.x - row.x >= row.buttonsStartX) {
            mouse.accepted = false;
            return;
          }
          root._contextIndex = i;
          var local = row.mapFromItem(contextArea, mouse.x, mouse.y);
          contextMenu.openAtItem(row, local.x, local.y);
          mouse.accepted = true;
          return;
        }
      }
      mouse.accepted = false;
    }
  }

  NContextMenu {
    id: contextMenu
    parent: Overlay.overlay
    width: 240 * Style.uiScaleRatio
    model: {
      var items = [];
      // Add move options for each available section (except current)
      for (var i = 0; i < root.availableSections.length; i++) {
        var section = root.availableSections[i];
        if (section !== root.sectionId) {
          var label = root.getSectionLabel(section);
          var displayLabel = '';
          // Map section IDs to correct position keys based on bar orientation
          var positionKey = section;
          if (root.barIsVertical) {
            if (section === "left")
              positionKey = "top";
            else if (section === "right")
              positionKey = "bottom";
          }
          if (I18n.hasTranslation("positions." + positionKey)) {
            displayLabel = I18n.tr("positions." + positionKey);
          } else {
            displayLabel = label.charAt(0).toUpperCase() + label.slice(1);
          }

          items.push({
                       "label": I18n.tr("tooltips.move-to-section", {
                                          "section": displayLabel
                                        }),
                       "action": section,
                       "icon": root.getSectionIcon(section),
                       "visible": true
                     });
        }
      }
      // Add remove option
      items.push({
                   "label": I18n.tr("tooltips.remove-widget"),
                   "action": "remove",
                   "icon": "trash",
                   "visible": true
                 });
      return items;
    }

    onTriggered: action => {
      if (root._contextIndex < 0)
        return;
      if (action === "remove") {
        root.removeWidget(root.sectionId, root._contextIndex);
      } else {
        root.moveWidget(root.sectionId, root._contextIndex, action);
      }
      root._contextIndex = -1;
    }
  }

  // MouseArea for drag and drop — sits above the rows but passes through
  // clicks it does not claim (gear area, add-row combo, head).
  MouseArea {
    id: flowDragArea
    anchors.fill: parent
    enabled: root.draggable || root.crossSectionDraggable

    acceptedButtons: Qt.LeftButton
    preventStealing: true // Always prevent stealing to ensure we get all events
    propagateComposedEvents: true // Allow events to propagate when not handled
    hoverEnabled: potentialDrag || dragStarted // Only track hover during drag operations
    cursorShape: dragStarted ? Qt.ClosedHandCursor : Qt.ArrowCursor

    property point startPos: Qt.point(0, 0)
    property bool dragStarted: false
    property bool potentialDrag: false // Track if we're in a potential drag interaction
    property int draggedIndex: -1
    property real dragThreshold: 8 // Reduced threshold for more responsive drag
    property Item draggedWidget: null
    property int dropTargetIndex: -1
    property var draggedModelData: null
    property bool isOverButtonArea: false

    // Insertion index for a vertical list: the first row whose vertical
    // centre sits below the cursor. The indicator is a horizontal line on
    // that seam (inserting at `count` shows the seam above the add row).
    function updateDropIndicator(mouseX, mouseY) {
      if (!dragStarted || draggedIndex === -1 || !root.draggable) {
        dropIndicator.opacity = 0;
        dropIndicator.pulsing = false;
        dropTargetIndex = -1;
        return;
      }

      var index = widgetModel.length;
      for (var i = 0; i < widgetModel.length; i++) {
        var row = widgetRepeater.itemAt(i);
        if (!row)
          continue;
        if (mouseY < row.y + row.height / 2) {
          index = i;
          break;
        }
      }

      // Inserting before ourselves or right after ourselves is a no-op.
      if (index === draggedIndex || index === draggedIndex + 1) {
        dropIndicator.opacity = 0;
        dropIndicator.pulsing = false;
        dropTargetIndex = -1;
        return;
      }

      dropTargetIndex = index > draggedIndex ? index - 1 : index;

      var seamY;
      if (index < widgetModel.length) {
        var target = widgetRepeater.itemAt(index);
        seamY = target ? target.y - group.spacing / 2 : 0;
      } else {
        var last = widgetRepeater.itemAt(widgetModel.length - 1);
        seamY = last ? last.y + last.height + group.spacing / 2 : comboBox.y - group.spacing / 2;
      }
      dropIndicator.y = seamY - dropIndicator.height / 2;
      dropIndicator.opacity = 1;
      dropIndicator.pulsing = true;
    }

    function resetDragState() {
      root.clearCrossSectionHover();
      dragStarted = false;
      potentialDrag = false;
      draggedIndex = -1;
      draggedWidget = null;
      dropTargetIndex = -1;
      draggedModelData = null;
      isOverButtonArea = false;
      dropIndicator.opacity = 0;
      dropIndicator.pulsing = false;
      dragGhost.width = 0;
    }

    onPressed: mouse => {
      // Reset state
      startPos = Qt.point(mouse.x, mouse.y);
      dragStarted = false;
      potentialDrag = false;
      draggedIndex = -1;
      draggedWidget = null;
      dropTargetIndex = -1;
      draggedModelData = null;
      isOverButtonArea = false;

      // Find which row was clicked
      for (var i = 0; i < widgetModel.length; i++) {
        const widget = widgetRepeater.itemAt(i);
        if (widget && widget.widgetIndex !== undefined) {
          if (mouse.y >= widget.y && mouse.y <= widget.y + widget.height && mouse.x >= widget.x && mouse.x <= widget.x + widget.width) {
            const localX = mouse.x - widget.x;

            if (localX >= widget.buttonsStartX && widget.buttonsCount > 0) {
              // Click is on button area - don't start drag, propagate event
              isOverButtonArea = true;
              mouse.accepted = false;
              return;
            } else {
              // This is a draggable area
              draggedIndex = widget.widgetIndex;
              draggedWidget = widget;
              draggedModelData = widget.modelData;
              potentialDrag = true;
              mouse.accepted = true;

              // Signal that interaction started (prevents panel close)
              root.dragPotentialStarted();
              return;
            }
          }
        }
      }

      // Click was not on any widget
      mouse.accepted = false;
    }

    onPositionChanged: mouse => {
      if (potentialDrag && draggedIndex !== -1) {
        const deltaX = mouse.x - startPos.x;
        const deltaY = mouse.y - startPos.y;
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

        // Start drag if threshold exceeded
        if (!dragStarted && distance > dragThreshold) {
          dragStarted = true;

          // Setup ghost widget
          if (draggedWidget) {
            dragGhost.width = draggedWidget.width;
            dragGhost.height = draggedWidget.height;
            dragGhost.color = Colors.overlay("field");
            ghostText.text = root.widgetDisplayName(draggedModelData.id);
          }

          var startGlobal = flowDragArea.mapToGlobal(mouse.x, mouse.y);
          root.updateCrossSectionHover(startGlobal.x, startGlobal.y);
        }

        if (dragStarted) {
          // Move ghost widget
          dragGhost.x = mouse.x - dragGhost.width / 2;
          dragGhost.y = mouse.y - dragGhost.height / 2;

          var moveGlobal = flowDragArea.mapToGlobal(mouse.x, mouse.y);
          root.updateCrossSectionHover(moveGlobal.x, moveGlobal.y);

          // Update drop indicator
          updateDropIndicator(mouse.x, mouse.y);
        }
      }
    }

    onReleased: mouse => {
      if (root.draggable && dragStarted && dropTargetIndex !== -1 && dropTargetIndex !== draggedIndex) {
        // Perform the reorder
        reorderWidget(sectionId, draggedIndex, dropTargetIndex);
      } else if (dragStarted && draggedIndex !== -1) {
        var globalPos = flowDragArea.mapToGlobal(mouse.x, mouse.y);
        var targetSectionId = root.findSectionAtGlobalPosition(globalPos.x, globalPos.y);
        if (targetSectionId !== "" && targetSectionId !== root.sectionId) {
          root.moveWidget(root.sectionId, draggedIndex, targetSectionId);
        }
      }

      // Always signal end of interaction if we started one
      if (potentialDrag) {
        root.dragPotentialEnded();
      }

      // Reset everything
      resetDragState();
      mouse.accepted = true;
    }

    onCanceled: {
      // Handle cancel (e.g., ESC key pressed during drag)
      if (potentialDrag) {
        root.dragPotentialEnded();
      }

      resetDragState();
    }
  }
}
