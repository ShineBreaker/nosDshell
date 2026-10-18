import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Plugins
import qs.Services.UI
import qs.Widgets

Popup {
  id: root
  enter: NPopupEnter {}
  exit: NPopupExit {}

  property int widgetIndex: -1
  property var widgetData: null
  property string widgetId: ""
  property string sectionId: "" // Not used for desktop widgets, but required by NSectionEditor
  property var screen: null
  property var settingsCache: ({})

  readonly property real maxHeight: (screen ? screen.height : (parent ? parent.height : 800)) * 0.8

  signal updateWidgetSettings(string section, int index, var settings)

  width: Math.max(content.implicitWidth + padding * 2, 500)
  height: Math.min(content.implicitHeight + padding * 2, maxHeight)
  padding: Style.marginXL
  modal: true
  closePolicy: Popup.NoAutoClose
  dim: false

  // Center in parent
  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)

  onOpened: {
    if (widgetData && widgetId) {
      loadWidgetSettings();
    }
    forceActiveFocus();
  }

  background: Rectangle {
    id: bgRect
    color: Color.maskShell
    radius: Style.radiusWindow
    border.color: Color.borderShell
    border.width: Style.borderM
  }

  contentItem: FocusScope {
    id: focusScope
    focus: true

    ColumnLayout {
      id: content
      anchors.fill: parent
      spacing: Style.marginM

      RowLayout {
        id: titleRow
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight

        NText {
          text: I18n.tr("system.widget-settings-title", {
                          "widget": DesktopWidgetRegistry.widgetDisplayName(root.widgetId)
                        })
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Color.onShell
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "close"
          tooltipText: I18n.tr("common.close")
          onClicked: saveAndClose()
        }
      }

      Rectangle {
        id: separator
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Color.overlay("hover")
      }

      // Scrollable settings area
      NScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 100
        gradientColor: Color.maskShell

        ColumnLayout {
          width: scrollView.availableWidth
          spacing: Style.marginM

          Loader {
            id: settingsLoader
            Layout.fillWidth: true
            onLoaded: {
              if (item) {
                Qt.callLater(() => {
                               var firstInput = findFirstFocusable(item);
                               if (firstInput) {
                                 firstInput.forceActiveFocus();
                               } else {
                                 focusScope.forceActiveFocus();
                               }
                             });
              }
            }

            function findFirstFocusable(item) {
              if (!item)
                return null;
              if (item.focus !== undefined && item.focus === true)
                return item;
              if (item.children) {
                for (var i = 0; i < item.children.length; i++) {
                  var child = item.children[i];
                  if (child && child.focus !== undefined && child.focus === true)
                    return child;
                  var found = findFirstFocusable(child);
                  if (found)
                    return found;
                }
              }
              return null;
            }
          }
        }
      }

      // Button bar separator (DDialog shape, same as NPluginSettingsPopup)
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Color.overlay("hover")
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        spacing: Style.marginM

        NButton {
          objectName: "widgetSettingsReset"
          text: I18n.tr("common.reset-to-default")
          icon: "restore"
          outlined: true
          onClicked: root.resetToDefaults()
        }

        Item {
          Layout.fillWidth: true
        }

        NButton {
          objectName: "widgetSettingsClose"
          text: I18n.tr("common.close")
          outlined: true
          onClicked: root.saveAndClose()
        }
      }
    }
  }

  // Mouse area for a draggable popup
  MouseArea {
    x: titleRow.x
    y: titleRow.y
    width: titleRow.width
    height: titleRow.height
    z: -1

    cursorShape: Qt.OpenHandCursor

    property real pressX: 0
    property real pressY: 0

    onPressed: mouse => {
                 pressX = mouse.x;
                 pressY = mouse.y;
                 cursorShape = Qt.ClosedHandCursor;
               }

    onReleased: {
      cursorShape = Qt.OpenHandCursor;
    }

    onPositionChanged: mouse => {
                         if (pressed) {
                           var deltaX = mouse.x - pressX;
                           var deltaY = mouse.y - pressY;

                           root.x += deltaX;
                           root.y += deltaY;
                         }
                       }
  }

  Timer {
    id: saveTimer
    running: false
    interval: 150
    onTriggered: {
      root.updateWidgetSettings(root.sectionId, root.widgetIndex, root.settingsCache);
    }
  }

  Connections {
    target: settingsLoader.item
    ignoreUnknownSignals: true
    function onSettingsChanged(newSettings) {
      if (newSettings) {
        root.settingsCache = newSettings;
        saveTimer.start();
      }
    }

    function onSettingsSaved(newSettings) {
      if (newSettings) {
        root.updateWidgetSettings(root.sectionId, root.widgetIndex, newSettings);
      }
    }
  }

  function saveAndClose() {
    if (settingsLoader.item && typeof settingsLoader.item.saveSettings === 'function') {
      var newSettings = settingsLoader.item.saveSettings();
      if (newSettings) {
        root.updateWidgetSettings(root.sectionId, root.widgetIndex, newSettings);
      }
    }
    root.close();
  }

  // Back to registry defaults: the registry rebuilds the entry as
  // {id, x, y, scale} + widgetMetadata (fresh-add shape, geometry kept), then
  // the page reloads — settings pages capture values into local state.
  function resetToDefaults() {
    if (!widgetId || widgetIndex < 0)
      return;
    saveTimer.stop();
    root.settingsCache = ({});
    DesktopWidgetRegistry.resetWidgetSettings(root.sectionId, root.widgetIndex);
    loadWidgetSettings();
    ToastService.showNotice(I18n.tr("system.widget-settings-title", {
                                      "widget": DesktopWidgetRegistry.widgetDisplayName(root.widgetId)
                                    }), I18n.tr("common.settings-reset"));
  }

  function loadWidgetSettings() {
    // Blank first: setSource() on the same URL only re-instantiates reliably
    // after the previous item is dropped.
    settingsLoader.source = "";
    // Re-read the saved entry so a reload after reset shows defaults, not
    // the widgetData snapshot this dialog was created with.
    var currentWidgetData = widgetData;
    var monitorWidgets = Settings.data.desktopWidgets.monitorWidgets || [];
    for (var i = 0; i < monitorWidgets.length; i++) {
      if (monitorWidgets[i].name === sectionId) {
        var stored = monitorWidgets[i].widgets || [];
        if (widgetIndex >= 0 && widgetIndex < stored.length) {
          currentWidgetData = stored[widgetIndex];
        }
        break;
      }
    }

    // Handle plugin widgets
    if (DesktopWidgetRegistry.isPluginWidget(widgetId)) {
      var pluginId = widgetId.replace("plugin:", "");
      var manifest = PluginRegistry.getPluginManifest(pluginId);

      var pluginDir = PluginRegistry.getPluginDir(pluginId);
      var loadVersion = PluginRegistry.pluginLoadVersions[pluginId] || 0;
      var api = PluginService.getPluginAPI(pluginId);

      var settingsPath;
      if (manifest && manifest.entryPoints && manifest.entryPoints.desktopWidgetSettings) {
        settingsPath = "file://" + pluginDir + "/" + manifest.entryPoints.desktopWidgetSettings;

        var widgetSettings = {};
        widgetSettings.data = currentWidgetData || {};
        widgetSettings.metadata = DesktopWidgetRegistry.widgetMetadata[widgetId] || {};
        widgetSettings.save = function () {
          var newSettings = Object.assign({}, widgetSettings.data);
          root.settingsCache = newSettings;
          saveTimer.start();
        };

        settingsLoader.setSource(settingsPath + "?v=" + loadVersion, {
                                   "pluginApi": api,
                                   "widgetSettings": widgetSettings
                                 });
      } else {
        Logger.w("DesktopWidgetSettingsDialog", "Plugin does not have desktop widget settings:", pluginId);

        // Fallback to the plugin settings
        if (manifest && manifest.entryPoints && manifest.entryPoints.settings) {
          settingsPath = "file://" + pluginDir + "/" + manifest.entryPoints.settings;

          settingsLoader.setSource(settingsPath + "?v=" + loadVersion, {
                                     "pluginApi": api
                                   });
        } else {
          Logger.w("DesktopWidgetSettingsDialog", "Plugin does not have settings:", pluginId);
        }
      }

      return;
    }

    // Handle core widgets
    const source = DesktopWidgetRegistry.widgetSettingsMap[widgetId];
    if (source) {
      var fullPath = Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/DesktopWidgets/" + source);
      settingsLoader.setSource(fullPath, {
                                 "widgetData": currentWidgetData,
                                 "widgetMetadata": DesktopWidgetRegistry.widgetMetadata[widgetId]
                               });
    }
  }
}
