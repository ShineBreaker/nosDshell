import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Services.Plugins
import qs.Services.UI
import qs.Widgets

NBox {
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
  property alias dropTargetArea: gridContainer

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

  readonly property int gridColumns: 3
  readonly property real miniButtonSize: Style.baseWidgetSize * 0.65
  readonly property bool isAtMaxCapacity: maxWidgets >= 0 && widgetModel.length >= maxWidgets
  readonly property real widgetItemHeight: Style.baseWidgetSize * 1.3 * Style.uiScaleRatio

  signal addWidget(string widgetId, string section)
  signal removeWidget(string section, int index)
  signal reorderWidget(string section, int fromIndex, int toIndex)
  signal updateWidgetSettings(string section, int index, var settings)
  signal moveWidget(string fromSection, int index, string toSection)
  signal dragPotentialStarted
  signal dragPotentialEnded
  signal openPluginSettingsRequested(var pluginManifest, string settingsEntryPoint)

  color: Colors.overlay("idle")
  Layout.fillWidth: true
  z: flowDragArea?.dragStarted ? 5000 : 0

  // Calculate width to fit gridColumns widgets with spacing
  function calculateWidgetWidth(gridWidth) {
    var columnSpacing = (root.gridColumns - 1) * Style.marginM;
    var widgetWidth = (gridWidth - columnSpacing) / root.gridColumns;
    return Math.floor(widgetWidth);
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

  Layout.minimumHeight: {
    // header + minimal content area
    var absoluteMin = Style.margin2L + (Style.fontSizeL * 2) + Style.marginM + (65 * Style.uiScaleRatio);

    var widgetCount = widgetModel.length;
    if (widgetCount === 0) {
      return absoluteMin;
    }

    // Calculate rows based on grid layout
    // Use actual parent width if available, otherwise estimate
    var availableWidth = (parent && parent.width > 0) ? (parent.width - Style.margin2L) : 400;
    var rows = Math.ceil(widgetCount / root.gridColumns);

    // Calculate widget width for height calculation
    var containerWidth = availableWidth;
    var widgetWidth = calculateWidgetWidth(containerWidth);

    // Header height + spacing + (rows * widget height) + (spacing between rows) + margins
    var headerHeight = Style.fontSizeL * 2;
    // Account for grid margins
    var gridTopMargin = Style.marginS;
    var gridBottomMargin = Style.marginL;
    var widgetAreaHeight = gridTopMargin + (rows * widgetItemHeight) + ((rows - 1) * Style.marginL) + gridBottomMargin;

    return Math.max(absoluteMin, Style.margin2L + headerHeight + Style.marginM + widgetAreaHeight);
  }

  // Plugin tiles get an accent-tinted border; the plugin NIcon inside marks
  // them too (widget tiles otherwise use one field-level chip colour).
  function tileBorderColor(widget) {
    if (root.widgetRegistry && root.widgetRegistry.isPluginWidget(widget.id)) {
      return Qt.alpha(Colors.accent, 0.45);
    }
    return "transparent";
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

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      Layout.rightMargin: Style.marginS

      ColumnLayout {
        spacing: Style.marginXXS
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: false
        Layout.leftMargin: Style.marginS
        Layout.maximumWidth: {
          // Reserve space for other elements: count indicator, combo box (~200), button (~50), and margins
          // Use a reasonable maximum that leaves room for controls on the right
          // On smaller screens, use a smaller percentage to ensure controls fit
          // The row's width is derived from the editor's, not read off the
          // row: the row resizes while it arranges its children, and a
          // constraint that follows it re-triggers the arrangement
          // ("Detected recursive rearrange").
          var rowWidth = root.width - 2 * Style.marginL - Style.marginS;
          if (rowWidth > 0) {
            // Use smaller percentage on smaller screens, but ensure minimum space for text
            var minWidth = 150 * Style.uiScaleRatio;
            var maxWidth = rowWidth < 600 ? rowWidth * 0.35 : rowWidth * 0.4;
            return Math.max(minWidth, maxWidth);
          }
          return 250 * Style.uiScaleRatio;
        }

        NText {
          text: sectionName
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Colors.onShell
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        NText {
          visible: sectionSubtitle !== ""
          text: sectionSubtitle
          pointSize: Style.fontSizeS
          color: Colors.onShellTertiary
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      // Widget count indicator (when max is set)
      NText {
        visible: root.maxWidgets >= 0
        text: root.maxWidgets === 0 ? "(LOCKED)" : "(" + widgetModel.length + "/" + root.maxWidgets + ")"
        pointSize: Style.fontSizeS
        color: root.isAtMaxCapacity ? Colors.alert : Colors.onShellTertiary
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Style.marginXS
      }

      Item {
        Layout.fillWidth: true
      }

      NSearchableComboBox {
        id: comboBox
        model: availableWidgets ?? null
        label: ""
        description: ""
        placeholder: I18n.tr("bar.section-editor.placeholder")
        searchPlaceholder: I18n.tr("bar.section-editor.search-placeholder")
        onSelected: key => comboBox.currentKey = key
        popupHeight: 300 * Style.uiScaleRatio
        minimumWidth: 200 * Style.uiScaleRatio
        enabled: !root.isAtMaxCapacity

        Layout.alignment: Qt.AlignVCenter

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

      NIconButton {
        icon: "add"
        colorBg: Colors.overlay("field")
        colorFg: Colors.onShell
        colorBgHover: Colors.overlay("checked")
        colorFgHover: Colors.onShell
        enabled: comboBox.currentKey !== "" && !root.isAtMaxCapacity
        tooltipText: root.isAtMaxCapacity ? I18n.tr("tooltips.max-widgets-reached") : I18n.tr("tooltips.add-widget")
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Style.marginS
        onClicked: {
          if (comboBox.currentKey !== "" && !root.isAtMaxCapacity) {
            addWidget(comboBox.currentKey, sectionId);
            comboBox.currentKey = "";
          }
        }
      }
    }

    // Drag and Drop Widget Area
    Item {
      id: gridContainer
      Layout.fillWidth: true
      Layout.preferredHeight: {
        if (widgetModel.length === 0) {
          return 65 * Style.uiScaleRatio;
        }
        // Use actual width, fallback to a reasonable default if not yet available
        var containerWidth = width > 0 ? width : (parent ? parent.width : 400);
        var rows = Math.ceil(widgetModel.length / root.gridColumns);
        // Calculate height: (rows * item height) + (row spacing between items) + grid margins
        var gridTopMargin = Style.marginS;
        var gridBottomMargin = Style.marginS;
        var calculatedHeight = gridTopMargin + (rows * root.widgetItemHeight) + ((rows - 1) * Style.marginS) + gridBottomMargin;
        return calculatedHeight;
      }
      Layout.minimumHeight: widgetModel.length === 0 ? (65 * Style.uiScaleRatio) : (Style.margin2S + root.widgetItemHeight)
      clip: !flowDragArea?.dragStarted

      Rectangle {
        anchors.fill: parent
        radius: Style.radiusItem
        color: Qt.alpha(Colors.accent, 0.12)
        border.color: Colors.accent
        border.width: Style.borderM
        visible: root.showCrossSectionDropHint
        z: 1500
      }

      Grid {
        id: widgetGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.marginS
        anchors.rightMargin: Style.marginS
        anchors.topMargin: Style.marginS
        anchors.bottomMargin: Style.marginS
        columns: root.gridColumns
        rowSpacing: Style.marginS
        columnSpacing: Style.marginM

        Repeater {
          id: widgetRepeater
          model: widgetRows

          delegate: Rectangle {
            id: widgetItem
            required property int index
            readonly property var modelData: (root.widgetModel && index >= 0 && index < root.widgetModel.length) ? root.widgetModel[index] : ({
                                                                                                                                                "id": ""
                                                                                                                                              })

            // id/parent refs dangle while the editor subtree is being
            // destroyed (二级页 pop) — bindings re-evaluate against torn-down
            // objects, so stay null-tolerant.
            width: root ? root.calculateWidgetWidth(parent ? parent.width : 0) : 0
            height: root.widgetItemHeight
            radius: Style.radiusItem
            // Field-level chip, same ladder step as NComboBox/NTextInput
            // fields (DESIGN §1.3); hover lifts one step.
            color: widgetItem.enabled ? (tileHover.containsMouse ? Colors.overlay("strong") : Colors.overlay("field")) : Colors.overlay("idle")
            border.color: root.tileBorderColor(modelData)
            border.width: Style.borderS

            HoverHandler {
              id: tileHover
            }

            // Store the widget index for drag operations
            property int widgetIndex: index
            readonly property int buttonsWidth: Math.round(20)
            readonly property int buttonsCount: root.widgetHasSettings(modelData.id) ? 1 : 0

            // Visual feedback during drag; dim the whole tile when the
            // editor subtree is disabled (same 0.6 as NToggle/NComboBox).
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

            // Context menu for moving widget to other sections
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
                             if (action === "remove") {
                               root.removeWidget(root.sectionId, widgetItem.index);
                             } else {
                               root.moveWidget(root.sectionId, widgetItem.index, action);
                             }
                           }
            }

            // MouseArea for the context menu - only active when not dragging
            MouseArea {
              id: contextMouseArea
              anchors.fill: parent
              acceptedButtons: Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              z: -1 // Below the buttons but above background
              enabled: !(flowDragArea?.dragStarted || flowDragArea?.potentialDrag)

              onPressed: mouse => {
                           mouse.accepted = true;
                           // Check if click is not on the settings button area (if visible)
                           const localX = mouse.x;
                           const buttonsStartX = parent.width - (parent.buttonsCount * parent.buttonsWidth);
                           if (localX < buttonsStartX || parent.buttonsCount === 0) {
                             contextMenu.openAtItem(widgetItem, mouse.x, mouse.y);
                           }
                         }
            }

            RowLayout {
              id: widgetContent
              anchors.fill: parent
              anchors.margins: Style.marginXS
              anchors.rightMargin: Style.marginS
              spacing: Style.marginXXS

              NText {
                text: {
                  // Localised label from the registry (plugin ids resolve to
                  // the manifest name inside); falls back to the raw id when
                  // no widgetDisplayName is available.
                  if (root.widgetRegistry && typeof root.widgetRegistry.widgetDisplayName === "function") {
                    return root.widgetRegistry.widgetDisplayName(modelData.id);
                  }
                  return modelData.id;
                }
                // widgetItem already dims the whole tile when disabled.
                autoDim: false
                pointSize: Style.fontSizeXS
                color: Colors.onShell
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: Style.marginS
                rightPadding: Style.marginS
                Layout.fillWidth: true
                Layout.fillHeight: true
              }

              // Plugin indicator icon
              NIcon {
                visible: root.widgetRegistry && root.widgetRegistry.isPluginWidget(modelData.id)
                icon: "plugin"
                pointSize: Style.fontSizeXXS
                color: Colors.onShell
                Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.5 : 0
                Layout.preferredHeight: Style.baseWidgetSize * 0.5
              }

              // CPU intensive indicator icon
              NIcon {
                visible: root.widgetRegistry && root.widgetRegistry.isCpuIntensive(modelData.id)
                icon: "cpu-intensive"
                pointSize: Style.fontSizeXXS
                color: Colors.onShell
                Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.5 : 0
                Layout.preferredHeight: Style.baseWidgetSize * 0.5
              }

              RowLayout {
                spacing: 0
                Layout.preferredWidth: buttonsCount * buttonsWidth * Style.uiScaleRatio
                Layout.preferredHeight: parent.height

                Loader {
                  active: root.widgetHasSettings(modelData.id) && root.enabled
                  sourceComponent: NIconButton {
                    // objectName lets `debug find` locate a widget's gear in
                    // verify scenes (hit-testing can't reach 25-deep rows);
                    // sectionId disambiguates the same widget across editors.
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
          }
        }
      }

      // Ghost/Clone widget for dragging
      Rectangle {
        id: dragGhost
        width: 0
        height: Style.baseWidgetSize * 1.15
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

      // Drop indicator - visual feedback for where the widget will be inserted
      Rectangle {
        id: dropIndicator
        width: 3
        height: Style.baseWidgetSize * 1.15
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

        Behavior on x {
          NAnim {
            duration: Style.animationFaster
            curve: "out"
          }
        }
        Behavior on y {
          NAnim {
            duration: Style.animationFaster
            curve: "out"
          }
        }
      }

      // MouseArea for drag and drop
      MouseArea {
        id: flowDragArea
        anchors.fill: parent
        z: 100 // Above widgets to ensure it captures events first
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

        // Drop position calculation
        // Map widget coordinates from grid-local to gridContainer coordinates
        function mapWidgetCoords(widget) {
          return {
            x: widget.x + widgetGrid.x,
            y: widget.y + widgetGrid.y,
            width: widget.width,
            height: widget.height
          };
        }

        function updateDropIndicator(mouseX, mouseY) {
          if (!dragStarted || draggedIndex === -1) {
            dropIndicator.opacity = 0;
            dropIndicator.pulsing = false;
            return;
          }

          let bestIndex = -1;
          let bestPosition = null;
          let minDistance = Infinity;

          // Check position relative to each widget
          for (var i = 0; i < widgetModel.length; i++) {
            if (i === draggedIndex)
              continue;
            const widget = widgetRepeater.itemAt(i);
            if (!widget || widget.widgetIndex === undefined)
              continue;

            const mapped = mapWidgetCoords(widget);

            // Check distance to left edge (insert before)
            const leftDist = Math.sqrt(Math.pow(mouseX - mapped.x, 2) + Math.pow(mouseY - (mapped.y + mapped.height / 2), 2));

            // Check distance to right edge (insert after)
            const rightDist = Math.sqrt(Math.pow(mouseX - (mapped.x + mapped.width), 2) + Math.pow(mouseY - (mapped.y + mapped.height / 2), 2));

            if (leftDist < minDistance) {
              minDistance = leftDist;
              bestIndex = i;
              bestPosition = Qt.point(mapped.x - dropIndicator.width / 2 - Style.marginXS, mapped.y);
            }

            if (rightDist < minDistance) {
              minDistance = rightDist;
              bestIndex = i + 1;
              bestPosition = Qt.point(mapped.x + mapped.width + Style.marginXS - dropIndicator.width / 2, mapped.y);
            }
          }

          // Check if we should insert at position 0 (very beginning)
          if (widgetModel.length > 0 && draggedIndex !== 0) {
            const firstWidget = widgetRepeater.itemAt(0);
            if (firstWidget) {
              const mapped = mapWidgetCoords(firstWidget);
              const dist = Math.sqrt(Math.pow(mouseX - mapped.x, 2) + Math.pow(mouseY - mapped.y, 2));
              if (dist < minDistance && mouseX < mapped.x + mapped.width / 2) {
                minDistance = dist;
                bestIndex = 0;
                // Position indicator to the left of the first widget
                bestPosition = Qt.point(mapped.x - dropIndicator.width / 2 - Style.marginXS, mapped.y);
              }
            }
          }

          // Only show indicator if we're close enough and it's a different position
          if (minDistance < 80 && bestIndex !== -1) {
            // Adjust index if we're moving forward
            let adjustedIndex = bestIndex;
            if (bestIndex > draggedIndex) {
              adjustedIndex = bestIndex - 1;
            }

            // Don't show if it's the same position
            if (adjustedIndex === draggedIndex) {
              dropIndicator.opacity = 0;
              dropIndicator.pulsing = false;
              dropTargetIndex = -1;
              return;
            }

            dropTargetIndex = adjustedIndex;
            if (bestPosition) {
              dropIndicator.x = bestPosition.x;
              dropIndicator.y = bestPosition.y;
              dropIndicator.opacity = 1;
              dropIndicator.pulsing = true;
            }
          } else {
            dropIndicator.opacity = 0;
            dropIndicator.pulsing = false;
            dropTargetIndex = -1;
          }
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

                     // Find which widget was clicked
                     for (var i = 0; i < widgetModel.length; i++) {
                       const widget = widgetRepeater.itemAt(i);
                       if (widget && widget.widgetIndex !== undefined) {
                         if (mouse.x >= widget.x && mouse.x <= widget.x + widget.width && mouse.y >= widget.y && mouse.y <= widget.y + widget.height) {
                           const localX = mouse.x - widget.x;
                           const buttonsStartX = widget.width - (widget.buttonsCount * widget.buttonsWidth * Style.uiScaleRatio);

                           if (localX >= buttonsStartX && widget.buttonsCount > 0) {
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
                                   dragGhost.color = Colors.overlay("field");
                                   ghostText.text = draggedModelData.id;
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
  }
}
