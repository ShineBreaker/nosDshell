import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Dock
import qs.Services.UI
import qs.Widgets

// DDE taskbar "Plugins" page: ordered editor for dock.plugins.
// Candidates mirror DockSettingsMenu.pluginCandidates (single source of
// truth); add/remove injects BarWidgetRegistry defaults the same way
// DockSettingsMenu.togglePlugin does. Reordering, drag and the per-plugin
// gear (BarWidgetSettingsDialog via sectionId "dock" -> Settings
// .setDockPluginSettings) come from NSectionEditor; the bar.widgets path
// is untouched.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  enabled: Settings.data.dock.enabled

  // Add a candidate id, preserving order and filling widget defaults.
  function _addPlugin(widgetId) {
    var plugins = (Settings.data.dock.plugins || []).slice();
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i] && plugins[i].id === widgetId)
        return;
    }
    var entry = {
      "id": widgetId
    };
    if (BarWidgetRegistry.widgetHasUserSettings(widgetId)) {
      var metadata = BarWidgetRegistry.widgetMetadata[widgetId];
      if (metadata) {
        Object.keys(metadata).forEach(function (key) {
          entry[key] = metadata[key];
        });
      }
    }
    plugins.push(entry);
    Settings.data.dock.plugins = plugins;
    BarService.widgetsRevision++;
  }

  function _removePlugin(index) {
    var plugins = (Settings.data.dock.plugins || []).slice();
    if (index < 0 || index >= plugins.length)
      return;
    plugins.splice(index, 1);
    Settings.data.dock.plugins = plugins;
    BarService.widgetsRevision++;
  }

  function _reorderPlugin(fromIndex, toIndex) {
    var plugins = (Settings.data.dock.plugins || []).slice();
    if (fromIndex < 0 || fromIndex >= plugins.length || toIndex < 0 || toIndex >= plugins.length || fromIndex === toIndex)
      return;
    var item = plugins.splice(fromIndex, 1)[0];
    plugins.splice(toIndex, 0, item);
    Settings.data.dock.plugins = plugins;
    BarService.widgetsRevision++;
  }

  function updateAvailablePlugins() {
    availablePlugins.clear();
    var ids = DockSettingsMenu.pluginCandidates || [];
    for (var i = 0; i < ids.length; i++) {
      if (BarWidgetRegistry.hasWidget(ids[i]))
        availablePlugins.append({
          "key": ids[i],
          "name": BarWidgetRegistry.widgetDisplayName(ids[i])
        });
    }
  }

  Component.onCompleted: {
    Qt.callLater(updateAvailablePlugins);
  }

  Connections {
    target: BarWidgetRegistry
    function onPluginWidgetRegistryUpdated() {
      updateAvailablePlugins();
    }
  }

  // Model entries bake I18n.tr results at append time; rebuild on language
  // change or (re)loaded translations.
  Connections {
    target: I18n
    function onTranslationsLoaded() {
      updateAvailablePlugins();
    }
  }

  ListModel {
    id: availablePlugins
  }

  NText {
    text: I18n.tr("settings.taskbar.plugins-description")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  NSectionEditor {
    sectionName: I18n.tr("settings.taskbar.plugins")
    sectionId: "dock"
    availableSections: ["dock"]
    settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml")
    widgetRegistry: BarWidgetRegistry
    widgetModel: Settings.data.dock.plugins
    availableWidgets: availablePlugins
    onAddWidget: (widgetId, section) => root._addPlugin(widgetId)
    onRemoveWidget: (section, index) => root._removePlugin(index)
    onReorderWidget: (section, fromIndex, toIndex) => root._reorderPlugin(fromIndex, toIndex)
    onUpdateWidgetSettings: (section, index, settings) => Settings.setDockPluginSettings(index, settings)
  }
}
