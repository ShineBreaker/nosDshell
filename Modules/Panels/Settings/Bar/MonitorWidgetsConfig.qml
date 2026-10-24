import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../../Helpers/QtObj2JS.js" as QtObj2JS
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Sectioned widget-layout editor (left / center / right).
// `editMode: "bar"` (default) edits a status-bar layout: `screen: null` writes
// Settings.data.bar.widgets, a bound screen writes that monitor's override.
// `editMode: "taskbar"` edits the taskbar layout both dock modes read:
// left/center zones live in dock.taskbarWidgets (Launcher/Taskbar are stored
// entries) and the right zone is dock.plugins. Efficient mode renders the
// three zones as its bar sections; fashion flattens them into a single strip
// (DockContent.contentList) — so one arrangement carries across modes.
ColumnLayout {
  id: root

  property var screen: null
  property string editMode: "bar" // "bar" | "taskbar"
  readonly property bool taskbarMode: editMode === "taskbar"
  readonly property string screenName: screen?.name || ""
  // determine bar orientation
  readonly property string barPosition: {
    if (taskbarMode)
      return screenName === "" ? Settings.data.dock.position : Settings.getTaskbarPositionForScreen(screenName);
    return screenName === "" ? Settings.data.bar.position : Settings.getBarPositionForScreen(screenName);
  }
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  Layout.fillWidth: true
  spacing: Style.marginM

  // Helper to get widgets for this screen (ensures override exists); the
  // global editor works on Settings.data.bar.widgets directly.
  function _getWidgetsContainer() {
    if (taskbarMode) {
      // Sliced copies: _saveWidgets reassigns fresh arrays so the editor's
      // effectiveWidgets binding re-evaluates on every mutation.
      var zones = Settings.data.dock.taskbarWidgets;
      return {
        "left": (zones && zones.left ? zones.left : []).slice(),
        "center": (zones && zones.center ? zones.center : []).slice(),
        "right": (Settings.data.dock.plugins || []).slice()
      };
    }
    if (screenName === "")
      return Settings.data.bar.widgets;
    if (!Settings.hasScreenOverride(screenName, "widgets")) {
      var currentWidgets = Settings.getBarWidgetsForScreen(screenName);
      var widgetsCopy = QtObj2JS.qtObjectToPlainObject(currentWidgets);
      Settings.setScreenOverride(screenName, "widgets", widgetsCopy);
    }
    var entry = Settings.getScreenOverrideEntry(screenName);
    return entry ? entry.widgets : Settings.data.bar.widgets;
  }

  // Persist widget changes by reassigning the override (triggers change detection)
  function _saveWidgets(widgets) {
    if (taskbarMode) {
      Settings.data.dock.taskbarWidgets.left = widgets.left;
      Settings.data.dock.taskbarWidgets.center = widgets.center;
      Settings.data.dock.plugins = widgets.right;
      return;
    }
    if (screenName === "") {
      Settings.data.bar.widgets = widgets;
    } else {
      Settings.setScreenOverride(screenName, "widgets", widgets);
    }
  }

  // Widget manipulation functions
  function _addWidgetToSection(widgetId, section) {
    var newWidget = {
      "id": widgetId
    };
    if (BarWidgetRegistry.widgetHasUserSettings(widgetId)) {
      var metadata = BarWidgetRegistry.widgetMetadata[widgetId];
      if (metadata) {
        Object.keys(metadata).forEach(function (key) {
          newWidget[key] = metadata[key];
        });
      }
    }
    var widgets = _getWidgetsContainer();
    widgets[section].push(newWidget);
    _saveWidgets(widgets);
    BarService.widgetsRevision++;
  }

  function _removeWidgetFromSection(section, index) {
    var widgets = _getWidgetsContainer();
    if (index >= 0 && index < widgets[section].length) {
      var newArray = widgets[section].slice();
      var removedWidgets = newArray.splice(index, 1);
      widgets[section] = newArray;
      _saveWidgets(widgets);
      BarService.widgetsRevision++;

      if (removedWidgets[0].id === "ControlCenter" && BarService.lookupWidget("ControlCenter") === undefined) {
        ToastService.showWarning(I18n.tr("toast.missing-control-center.label"), I18n.tr("toast.missing-control-center.description"), 12000);
      }
      // The taskbar loses its app list — recoverable by re-adding Taskbar,
      // but warn the same way the bar does for ControlCenter.
      if (taskbarMode && removedWidgets[0].id === "Taskbar") {
        ToastService.showWarning(I18n.tr("toast.missing-taskbar-apps.label"), I18n.tr("toast.missing-taskbar-apps.description"), 12000);
      }
    }
  }

  function _reorderWidgetInSection(section, fromIndex, toIndex) {
    var widgets = _getWidgetsContainer();
    if (fromIndex >= 0 && fromIndex < widgets[section].length && toIndex >= 0 && toIndex < widgets[section].length) {
      var newArray = widgets[section].slice();
      var item = newArray[fromIndex];
      newArray.splice(fromIndex, 1);
      newArray.splice(toIndex, 0, item);
      widgets[section] = newArray;
      _saveWidgets(widgets);
      BarService.widgetsRevision++;
    }
  }

  // Note: _updateWidgetSettingsInSection does NOT increment revision
  // because it only changes settings, not widget structure
  function _updateWidgetSettingsInSection(section, index, settings) {
    var widgets = _getWidgetsContainer();
    var existing = widgets[section] && widgets[section][index];
    if (!existing || !settings)
      return;
    // The entry id is structural, not a setting — a payload must never rename
    // the slot (a stale/misdirected payload once overwrote the Taskbar entry
    // with another widget's id and the app strip vanished). Inject the id when
    // the payload lacks it and keep the slot's id when they disagree.
    var entry = Object.assign({}, settings);
    if (existing.id && entry.id !== existing.id) {
      if (entry.id !== undefined)
        Logger.w("MonitorWidgetsConfig", "settings payload id '" + entry.id + "' does not match slot id '" + existing.id + "' — keeping entry identity");
      entry.id = existing.id;
    }
    widgets[section][index] = entry;
    _saveWidgets(widgets);
  }

  function _moveWidgetBetweenSections(fromSection, index, toSection) {
    var widgets = _getWidgetsContainer();
    if (index >= 0 && index < widgets[fromSection].length) {
      var widget = widgets[fromSection][index];
      var sourceArray = widgets[fromSection].slice();
      sourceArray.splice(index, 1);
      widgets[fromSection] = sourceArray;
      var targetArray = widgets[toSection].slice();
      targetArray.push(widget);
      widgets[toSection] = targetArray;
      _saveWidgets(widgets);
      BarService.widgetsRevision++;
    }
  }

  // Available widgets ListModel
  function updateAvailableWidgetsModel() {
    availableWidgetsModel.clear();
    var widgetIds = BarWidgetRegistry.getAvailableWidgets();
    if (!widgetIds)
      return;
    for (var i = 0; i < widgetIds.length; i++) {
      var id = widgetIds[i];
      // widgetDisplayName already resolves plugin ids to the manifest name.
      var displayName = BarWidgetRegistry.widgetDisplayName(id);
      const badges = [];
      if (BarWidgetRegistry.isPluginWidget(id)) {
        badges.push({
                      "icon": "plugin",
                      "color": Colors.accentAlt
                    });
      }
      if (BarWidgetRegistry.isCpuIntensive(id)) {
        badges.push({
                      "icon": "cpu-intensive",
                      "color": Colors.accentAlt
                    });
      }
      availableWidgetsModel.append({
                                     "key": id,
                                     "name": displayName,
                                     "badges": badges
                                   });
    }
  }

  Component.onCompleted: Qt.callLater(function () {
    updateAvailableWidgetsModel();
  })

  // Model entries bake I18n.tr results at append time; rebuild on language
  // change or (re)loaded translations.
  Connections {
    target: I18n
    function onTranslationsLoaded() {
      updateAvailableWidgetsModel();
    }
  }

  // Plugin widgets register asynchronously — entries that arrive after the
  // first model build would be un-addable until the next language change.
  Connections {
    target: BarWidgetRegistry
    function onPluginWidgetRegistryUpdated() {
      updateAvailableWidgetsModel();
    }
  }

  ListModel {
    id: availableWidgetsModel
  }

  // Get effective widgets: global default when unbound, per-screen otherwise;
  // in taskbar mode a synthesized view over dock.taskbarWidgets + dock.plugins.
  readonly property var effectiveWidgets: {
    if (taskbarMode) {
      var zones = Settings.data.dock.taskbarWidgets;
      return {
        "left": (zones && zones.left) || [],
        "center": (zones && zones.center) || [],
        "right": Settings.data.dock.plugins || []
      };
    }
    return screenName === "" ? Settings.data.bar.widgets : Settings.getBarWidgetsForScreen(screenName);
  }

  NText {
    text: root.taskbarMode ? I18n.tr("settings.taskbar.widgets-description") : I18n.tr("panels.bar.widgets-desc")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  // Left Section
  NSectionEditor {
    sectionName: root.barIsVertical ? I18n.tr("positions.top") : I18n.tr("positions.left")
    sectionSubtitle: root.taskbarMode ? I18n.tr("settings.taskbar.zone-leading-subtitle") : ""
    sectionId: "left"
    barIsVertical: root.barIsVertical
    screen: root.screen
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: root.effectiveWidgets.left
    availableWidgets: availableWidgetsModel
    onAddWidget: (widgetId, section) => root._addWidgetToSection(widgetId, section)
    onRemoveWidget: (section, index) => root._removeWidgetFromSection(section, index)
    onReorderWidget: (section, fromIndex, toIndex) => root._reorderWidgetInSection(section, fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => root._updateWidgetSettingsInSection(section, index, settings)
    onMoveWidget: (fromSection, index, toSection) => root._moveWidgetBetweenSections(fromSection, index, toSection)
    onOpenPluginSettingsRequested: (manifest, entryPoint) => root._openPluginSettings(manifest, entryPoint)
  }

  // Center Section
  NSectionEditor {
    sectionName: I18n.tr("positions.center")
    sectionSubtitle: root.taskbarMode ? I18n.tr("settings.taskbar.zone-center-subtitle") : ""
    sectionId: "center"
    barIsVertical: root.barIsVertical
    screen: root.screen
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: root.effectiveWidgets.center
    availableWidgets: availableWidgetsModel
    onAddWidget: (widgetId, section) => root._addWidgetToSection(widgetId, section)
    onRemoveWidget: (section, index) => root._removeWidgetFromSection(section, index)
    onReorderWidget: (section, fromIndex, toIndex) => root._reorderWidgetInSection(section, fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => root._updateWidgetSettingsInSection(section, index, settings)
    onMoveWidget: (fromSection, index, toSection) => root._moveWidgetBetweenSections(fromSection, index, toSection)
    onOpenPluginSettingsRequested: (manifest, entryPoint) => root._openPluginSettings(manifest, entryPoint)
  }

  // Right Section — the plugin strip in taskbar mode (dock.plugins).
  // Candidates are the same full registry list as the other zones: the fashion
  // dock flattens all three zones into one strip, so any widget is legal there.
  NSectionEditor {
    sectionName: root.taskbarMode ? I18n.tr("settings.taskbar.plugins") : (root.barIsVertical ? I18n.tr("positions.bottom") : I18n.tr("positions.right"))
    sectionSubtitle: root.taskbarMode ? I18n.tr("settings.taskbar.zone-plugins-subtitle") : ""
    sectionId: "right"
    barIsVertical: root.barIsVertical
    screen: root.screen
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: root.effectiveWidgets.right
    availableWidgets: availableWidgetsModel
    onAddWidget: (widgetId, section) => root._addWidgetToSection(widgetId, section)
    onRemoveWidget: (section, index) => root._removeWidgetFromSection(section, index)
    onReorderWidget: (section, fromIndex, toIndex) => root._reorderWidgetInSection(section, fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => root._updateWidgetSettingsInSection(section, index, settings)
    onMoveWidget: (fromSection, index, toSection) => root._moveWidgetBetweenSections(fromSection, index, toSection)
    onOpenPluginSettingsRequested: (manifest, entryPoint) => root._openPluginSettings(manifest, entryPoint)
  }

  // Host plugin settings on the popup window surface like BarWidgetSettingsDialog
  // (NSectionEditor): that surface owns the dialog blur region + click-outside
  // close; Overlay.overlay on the settings panel surface has neither.
  function _openPluginSettings(manifest, entryPoint) {
    PanelService.hostSettingsPopup(pluginSettingsDialog, root.screen);
    pluginSettingsDialog.openPluginSettings(manifest, entryPoint);
  }

  // Plugin settings dialog
  NPluginSettingsPopup {
    id: pluginSettingsDialog
    parent: Overlay.overlay
    showToastOnSave: false
  }
}
