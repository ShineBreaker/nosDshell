import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Plugins
import qs.Services.UI
import qs.Widgets

Popup {
  id: root
  modal: true
  dim: false
  enter: NPopupEnter {}
  exit: NPopupExit {}
  anchors.centerIn: parent
  property var screen: null
  readonly property real maxHeight: (screen ? screen.height : (parent ? parent.height : 800)) * 0.8

  property real _minWidth: 600 * Style.uiScaleRatio
  width: _minWidth
  height: Math.min(settingsContent.implicitHeight + padding * 2, maxHeight)
  padding: Style.marginXL

  property var currentPlugin: null
  property var currentPluginApi: null
  property bool showToastOnSave: false
  // The URL handed to settingsLoader — kept so reset can reload the page and
  // controls re-read the restored defaults (pages cache values at load).
  property string _settingsSource: ""

  background: Rectangle {
    color: Colors.maskShell
    radius: Style.radiusWindow
    border.color: Colors.borderShell
    border.width: Style.borderS
  }

  contentItem: FocusScope {
    focus: true

    ColumnLayout {
      id: settingsContent
      anchors.fill: parent
      spacing: Style.marginM

      // Header
      RowLayout {
        Layout.fillWidth: true

        NText {
          text: I18n.tr("panels.plugins.plugin-settings-title", {
                          "plugin": PluginRegistry.pluginDisplayName(root.currentPlugin)
                        })
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightSemiBold
          color: Colors.onShell
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "close"
          tooltipText: I18n.tr("common.close")
          onClicked: root.close()
        }
      }

      // Separator
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Colors.overlay("hover")
      }

      // Settings loader - pluginApi is passed via setSource() in openPluginSettings()
      NScrollView {
        id: settingsScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 100
        horizontalPolicy: ScrollBar.AlwaysOff

        Loader {
          id: settingsLoader
          width: settingsScrollView.availableWidth
        }
      }

      // DDialog button bar separator
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Colors.overlay("hover")
      }

      // Action buttons: destructive-ish actions left, safe actions right.
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        spacing: Style.marginM

        NButton {
          objectName: "pluginSettingsReset"
          text: I18n.tr("common.reset-to-default")
          icon: "restore"
          outlined: true
          onClicked: root.resetToDefaults()
        }

        Item {
          Layout.fillWidth: true
        }

        NButton {
          objectName: "pluginSettingsClose"
          text: I18n.tr("common.close")
          outlined: true
          onClicked: root.close()
        }

        NButton {
          text: I18n.tr("common.apply")
          icon: "check"
          backgroundColor: Colors.mPrimary // recommended action → accent text
          onClicked: {
            if (settingsLoader.item && settingsLoader.item.saveSettings) {
              settingsLoader.item.saveSettings();
              if (root.showToastOnSave) {
                ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.settings-saved"));
              }
            }
          }
        }
      }
    }
  }

  onClosed: {
    // Clear both source and sourceComponent to ensure full cleanup
    settingsLoader.sourceComponent = null;
    settingsLoader.source = "";
    currentPlugin = null;
    currentPluginApi = null;
    _settingsSource = "";
  }

  // Restore manifest.metadata.defaultSettings: persist the defaults to the
  // plugin's settings.json, then reload the page so its controls re-read
  // them (settings pages capture pluginSettings into local state on load).
  function resetToDefaults() {
    if (!currentPluginApi)
      return;
    var defaults = currentPluginApi.manifest?.metadata?.defaultSettings || {};
    currentPluginApi.pluginSettings = JSON.parse(JSON.stringify(defaults));
    currentPluginApi.saveSettings();
    if (_settingsSource !== "") {
      settingsLoader.source = "";
      settingsLoader.setSource(_settingsSource, {
                                 "pluginApi": currentPluginApi
                               });
    }
    if (showToastOnSave) {
      ToastService.showNotice(I18n.tr("panels.plugins.plugin-settings-title", {
                                        "plugin": currentPlugin?.name || ""
                                      }), I18n.tr("common.settings-reset"));
    }
  }

  function openPluginSettings(pluginManifest, settingsEntryPoint) {
    currentPlugin = pluginManifest;

    // Use composite key if available (for custom plugins), otherwise use manifest ID (for official plugins)
    var pluginId = pluginManifest.compositeKey || pluginManifest.id;

    currentPluginApi = PluginService.getPluginAPI(pluginId);
    if (!currentPluginApi) {
      Logger.e("NPluginSettingsPopup", "Cannot open settings: plugin not loaded:", pluginId);
      if (showToastOnSave) {
        ToastService.showError(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.settings-error-not-loaded"));
      }
      return;
    }

    // Get plugin directory
    var pluginDir = PluginRegistry.getPluginDir(pluginId);
    var settingsEntry = settingsEntryPoint ? pluginManifest.entryPoints[settingsEntryPoint] : pluginManifest.entryPoints.settings;
    var settingsPath = pluginDir + "/" + settingsEntry;

    _settingsSource = "file://" + settingsPath;
    settingsLoader.setSource(_settingsSource, {
                               "pluginApi": currentPluginApi
                             });

    var preferred = (settingsLoader.item && settingsLoader.item.preferredWidth !== undefined) ? settingsLoader.item.preferredWidth + padding * 2 : 0;
    width = Math.max(preferred, _minWidth);
    open();
  }
}
