import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Widget Settings Dialog Component
Popup {
  id: root
  enter: NPopupEnter {}
  exit: NPopupExit {}

  property int widgetIndex: -1
  property var widgetData: null
  property string widgetId: ""
  property string sectionId: ""
  property var screen: null
  property bool barIsVertical: false
  property var settingsCache: ({})

  readonly property real maxHeight: (screen ? screen.height : (parent ? parent.height : 800)) * 0.8

  signal updateWidgetSettings(string section, int index, var settings)

  width: Math.max(content.implicitWidth + padding * 2, 640)
  height: Math.min(content.implicitHeight + padding * 2, maxHeight)
  padding: Style.marginXL
  modal: true
  closePolicy: Popup.NoAutoClose
  dim: false
  anchors.centerIn: parent

  onOpened: {
    // Load settings when popup opens with data
    if (widgetData && widgetId) {
      loadWidgetSettings();
    }
    // Request focus to ensure keyboard input works
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

      // Title
      RowLayout {
        id: titleRow
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight

        NText {
          text: I18n.tr("system.widget-settings-title", {
                          "widget": root.widgetId
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

      // Separator
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

          // Settings based on widget type
          // Will be triggered via settingsLoader.setSource()
          Loader {
            id: settingsLoader
            Layout.fillWidth: true
            onLoaded: {
              // Settings pages that declare a `sectionId` property get the
              // dialog's context (e.g. Workspace hides pill-only controls in
              // the dock where the widget renders squares, not pills).
              if (item && item.sectionId !== undefined)
                item.sectionId = root.sectionId;
              // Try to focus the first focusable item in the loaded settings
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
              // Check if this item can accept focus
              if (item.focus !== undefined && item.focus === true)
                return item;
              // Check children
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

  // Back to registry defaults: the entry becomes exactly what a fresh add
  // writes ({id} + widgetMetadata). The write replaces the entry, so stale
  // saved keys drop out; then reload the page — settings pages capture
  // values into local state on load.
  function resetToDefaults() {
    if (!widgetId || widgetIndex < 0)
      return;
    var metadata = BarWidgetRegistry.widgetMetadata[widgetId] || {};
    var entry = {
      "id": widgetId
    };
    Object.keys(metadata).forEach(function (key) {
      entry[key] = metadata[key];
    });
    saveTimer.stop();
    root.settingsCache = ({});
    root.updateWidgetSettings(root.sectionId, root.widgetIndex, entry);
    loadWidgetSettings();
    ToastService.showNotice(I18n.tr("system.widget-settings-title", {
                                    "widget": root.widgetId
                                  }), I18n.tr("common.settings-reset"));
  }

  function loadWidgetSettings() {
    // Blank first: setSource() on the same URL only re-instantiates reliably
    // after the previous item is dropped.
    settingsLoader.source = "";
    const source = BarWidgetRegistry.widgetSettingsMap[widgetId];
    if (source) {
      var currentWidgetData = widgetData;
      if (sectionId && widgetIndex >= 0) {
        var widgets = Settings.getBarWidgetsForScreen(screen?.name || "")[sectionId];
        if (widgets && widgetIndex < widgets.length) {
          currentWidgetData = widgets[widgetIndex];
        }
      }
      settingsLoader.setSource(source, {
                                 "screen": screen,
                                 "widgetData": currentWidgetData,
                                 "widgetMetadata": BarWidgetRegistry.widgetMetadata[widgetId]
                               });
    }
  }
}
